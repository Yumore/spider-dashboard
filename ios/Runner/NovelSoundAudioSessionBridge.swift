import AVFoundation
import Flutter
import MediaPlayer
import UIKit

// MARK: - 锁屏 / 控制中心 / 耳机键（iOS 的媒体会话）
//
// 安卓侧由 `ListenKeepAliveService` 提供前台服务 + MediaSessionCompat；iOS 没有
// 等价物，必须自己组合 AVAudioSession（让音频在后台继续）+ MPNowPlayingInfoCenter
// （锁屏与任务切换器里的卡片）+ MPRemoteCommandCenter（锁屏按钮、耳机线控、
// 车机与蓝牙按键）。Dart 侧只在播放状态变化时推一次元数据，收到的远端命令
// 复用安卓那套 `_handleRemoteAction`，两端行为因此一致。
//
//   MethodChannel `fqapp/audio_session`        "update" / "stop"
//   EventChannel  `fqapp/audio_session/events` play / pause / playPause / next / prev / seek / stop
final class AudioSessionBridge: NSObject {
  private static let methodName = "fqapp/audio_session"
  private static let eventName = "fqapp/audio_session/events"

  private static var sink: FlutterEventSink?
  static var guomuRemoteCommandHandler: ((String, Double?) -> Void)?
  static var hasActiveOwner: Bool { owner != nil }
  private static var owner: String?
  private static var sessionID = 0
  private static var intent = 0
  private static var interruptedSession: Int?
  private static var interrupted = false
  private static var configured = false
  private static var sessionActive = false
  private static var playing = false
  private static var backgroundWindows: [Int: UIBackgroundTaskIdentifier] = [:]
  private static var nextBackgroundWindow = 0
  private static var artwork: MPMediaItemArtwork?
  private static var artworkKey: String?
  private static var artworkTask: URLSessionDataTask?

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: methodName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
#if DEBUG
      case "debugSnapshot":
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        result([
          "owner": owner as Any? ?? NSNull(),
          "session": sessionID,
          "playing": playing,
          "title": info[MPMediaItemPropertyTitle] ?? NSNull(),
          "category": AVAudioSession.sharedInstance().category.rawValue,
          "mode": AVAudioSession.sharedInstance().mode.rawValue,
        ])
#endif
      case "claim":
        guard let args = call.arguments as? [String: Any],
              let newOwner = args["owner"] as? String,
              let newSession = args["session"] as? Int,
              newSession > sessionID else { result(nil); return }
        clearMedia()
        owner = newOwner
        sessionID = newSession
        intent = args["intent"] as? Int ?? 0
        result(nil)
      case "cancelInterruption":
        if let args = call.arguments as? [String: Any], matches(args),
           (args["intent"] as? Int ?? -1) >= intent {
          intent = args["intent"] as? Int ?? intent
          interruptedSession = nil
        }
        result(nil)
      case "prepare":
        if let args = call.arguments as? [String: Any], matches(args) {
          configureSession(args["mode"] as? String ?? "audio")
          activateSession()
        }
        result(nil)
      case "setPlaying":
        if let args = call.arguments as? [String: Any], matches(args),
           (args["intent"] as? Int ?? -1) >= intent {
          playing = args["playing"] as? Bool ?? false
          let center = MPNowPlayingInfoCenter.default()
          if center.nowPlayingInfo != nil {
            center.playbackState = playing ? .playing : .paused
            if !playing { center.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0.0 }
          }
        }
        result(nil)
      case "releaseIfIdle":
        if let args = call.arguments as? [String: Any], owner == nil,
           args["session"] as? Int == sessionID {
          deactivateSession()
        }
        result(nil)
      case "update":
        guard let arguments = call.arguments as? [String: Any] else {
          result(FlutterError(code: "BAD_ARGUMENT", message: "缺少媒体元数据", details: nil))
          return
        }
        if matches(arguments), (arguments["intent"] as? Int ?? -1) >= intent {
          intent = arguments["intent"] as? Int ?? intent
          apply(arguments)
        }
        result(nil)
      case "beginBackgroundWindow":
        guard let args = call.arguments as? [String: Any], matches(args) else {
          result(nil)
          return
        }
        nextBackgroundWindow += 1
        let token = nextBackgroundWindow
        let task = UIApplication.shared.beginBackgroundTask(withName: "fqapp-chapter-switch") {
          endBackgroundWindow(token)
        }
        if task == .invalid { result(nil); return }
        backgroundWindows[token] = task
        result(token)
      case "endBackgroundWindow":
        if let args = call.arguments as? [String: Any], let token = args["token"] as? Int {
          endBackgroundWindow(token)
        }
        result(nil)
      case "stop":
        if let args = call.arguments as? [String: Any], matches(args) {
          teardown()
          owner = nil
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    FlutterEventChannel(name: eventName, binaryMessenger: messenger)
      .setStreamHandler(NovelSoundAudioSessionEvents())
    // 冷启动不主动激活音频会话：没有音频在播时抢会话既没必要，在 CI 的
    // 无声模拟器上还可能拖慢启动。第一次 update 会按 mode 配置并激活。
    registerCommands()
    observeInterruptions()
  }

  private static func endBackgroundWindow(_ token: Int) {
    guard let task = backgroundWindows.removeValue(forKey: token) else { return }
    UIApplication.shared.endBackgroundTask(task)
  }

  private static func matches(_ arguments: [String: Any]) -> Bool {
    owner != nil && arguments["owner"] as? String == owner &&
      arguments["session"] as? Int == sessionID
  }

  // MARK: - 会话

  /// 当前音频会话的用途：`audio` 是听书（长语音），`video` 是影视。
  private static var sessionMode = ""

  private static func configureSession(_ mode: String = "audio") {
    let session = AVAudioSession.sharedInstance()
    // 听书是长语音，走 spokenAudio：静音键不打断，也不会启用系统为音乐准备的
    // 空间音频；影视要走 moviePlayback，否则 AirPods 的语音优化会压到音轨上。
    let wanted = mode == "video" ? AVAudioSession.Mode.moviePlayback
                                 : AVAudioSession.Mode.spokenAudio
    let changed = !configured || sessionMode != mode
    guard changed else { return }
    do {
      try session.setCategory(.playback, mode: wanted, options: [])
      configured = true
      sessionMode = mode
    } catch {
      configured = false
      NSLog("audio session category failed: \(error.localizedDescription)")
    }
  }

  private static func activateSession() {
    guard configured, !interrupted else { return }
    do {
      try AVAudioSession.sharedInstance().setActive(true, options: [])
      sessionActive = true
    } catch {
      sessionActive = false
      NSLog("audio session activate failed: \(error.localizedDescription)")
    }
  }

  private static func apply(_ arguments: [String: Any]) {
    configureSession(arguments["mode"] as? String ?? "audio")
    // 只有 playing 为真才强行激活：暂停时保持会话，让锁屏卡片留在原地。
    let nowPlaying = arguments["playing"] as? Bool ?? false
    if nowPlaying { activateSession() }
    playing = nowPlaying

    let title = arguments["title"] as? String ?? ""
    let episode = arguments["episode"] as? String ?? ""
    let positionMs = arguments["positionMs"] as? Int ?? 0
    let durationMs = arguments["durationMs"] as? Int ?? 0
    let rate = arguments["rate"] as? Double ?? 1
    let hasPrev = arguments["hasPrev"] as? Bool ?? false
    let hasNext = arguments["hasNext"] as? Bool ?? false
    let cover = arguments["cover"] as? String ?? ""

    var info: [String: Any] = [
      MPMediaItemPropertyTitle: title.isEmpty ? "什锦铺" : title,
      MPMediaItemPropertyAlbumTitle: episode,
      MPMediaItemPropertyPlaybackDuration: Double(durationMs) / 1000.0,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(positionMs) / 1000.0,
      MPNowPlayingInfoPropertyPlaybackRate: nowPlaying ? rate : 0.0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: rate,
      MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
      MPNowPlayingInfoPropertyIsLiveStream: false,
      MPMediaItemPropertyAlbumTrackNumber: 1,
    ]
    if cover != artworkKey {
      artwork = nil
      artworkKey = nil
      artworkTask?.cancel()
    }
    if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    MPNowPlayingInfoCenter.default().playbackState = nowPlaying ? .playing : .paused

    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtist] = episode

    commands(enabled: true, hasPrev: hasPrev, hasNext: hasNext)
    if !cover.isEmpty { loadArtwork(coverURL: cover) }
  }

  private static func loadArtwork(coverURL: String) {
    guard coverURL != artworkKey else { return }
    artworkKey = coverURL
    artworkTask?.cancel()
    guard let url = URL(string: coverURL) else { return }
    // 封面来自 CDN，下载失败只是没有大图，不影响播放。
    let artworkSession = sessionID
    artworkTask = URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data, let image = UIImage(data: data) else { return }
      let cover = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
      DispatchQueue.main.async {
        guard coverURL == artworkKey, artworkSession == sessionID, owner != nil else { return }
        artwork = cover
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = cover
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      }
    }
    artworkTask?.resume()
  }

  private static func clearMedia() {
    for token in Array(backgroundWindows.keys) { endBackgroundWindow(token) }
    playing = false
    interruptedSession = nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped
    commands(enabled: false, hasPrev: false, hasNext: false)
    artwork = nil
    artworkKey = nil
    artworkTask?.cancel()
    artworkTask = nil
  }

  private static func teardown() {
    clearMedia()
    deactivateSession()
  }

  private static func deactivateSession() {
    guard sessionActive else { return }
    do {
      // notifyOthersOnDeactivation：让别的 App（音乐、播客）能接着播。
      try AVAudioSession.sharedInstance().setActive(
        false, options: [.notifyOthersOnDeactivation])
      sessionActive = false
    } catch {
      NSLog("audio session deactivate failed: \(error.localizedDescription)")
    }
  }

  // MARK: - 远端命令

  private static func commands(enabled: Bool, hasPrev: Bool, hasNext: Bool) {
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.isEnabled = enabled
    center.pauseCommand.isEnabled = enabled
    center.togglePlayPauseCommand.isEnabled = enabled
    center.stopCommand.isEnabled = enabled
    center.changePlaybackPositionCommand.isEnabled = enabled
    center.previousTrackCommand.isEnabled = enabled && hasPrev
    center.nextTrackCommand.isEnabled = enabled && hasNext
    center.skipForwardCommand.isEnabled = false
    center.skipBackwardCommand.isEnabled = false
  }

  /// Guomu uses the same system command center while it owns Now Playing.
  /// Novel Sound takes precedence whenever it has claimed an audio session.
  static func setGuomuCommandAvailability(_ enabled: Bool) {
    guard owner == nil else { return }
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.isEnabled = enabled
    center.pauseCommand.isEnabled = enabled
    center.togglePlayPauseCommand.isEnabled = enabled
    center.changePlaybackPositionCommand.isEnabled = enabled
    center.stopCommand.isEnabled = false
    center.previousTrackCommand.isEnabled = false
    center.nextTrackCommand.isEnabled = false
  }

  private static func registerCommands() {
    let center = MPRemoteCommandCenter.shared()

    func handler(_ action: String) -> (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
      return { _ in
        if action == "pause" || action == "stop" || action == "playPause" ||
           action == "next" || action == "prev" {
          interruptedSession = nil
        }
        dispatchRemoteCommand(action)
        return .success
      }
    }

    center.playCommand.addTarget { handler("play")($0) }
    center.pauseCommand.addTarget { handler("pause")($0) }
    center.togglePlayPauseCommand.addTarget { handler("playPause")($0) }
    center.stopCommand.addTarget { handler("stop")($0) }
    center.nextTrackCommand.addTarget { handler("next")($0) }
    center.previousTrackCommand.addTarget { handler("prev")($0) }
    center.changePlaybackPositionCommand.addTarget { event in
      guard let seek = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      dispatchRemoteCommand("seek", positionSeconds: seek.positionTime)
      return .success
    }
    commands(enabled: false, hasPrev: false, hasNext: false)
  }

  private static func dispatchRemoteCommand(
    _ action: String,
    positionSeconds: Double? = nil
  ) {
    guard owner != nil else {
      guomuRemoteCommandHandler?(action, positionSeconds)
      return
    }
    var payload: [String: Any] = ["action": action]
    if let positionSeconds {
      payload["positionMs"] = Int(positionSeconds * 1000)
    }
    emit(payload)
  }

  // MARK: - 中断与路由变化

  private static func observeInterruptions() {
    let center = NotificationCenter.default
    center.addObserver(
      forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
    ) { note in
      guard
        let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        let type = AVAudioSession.InterruptionType(rawValue: raw)
      else { return }
      switch type {
      case .began:
        guard !interrupted else { return }
        interrupted = true
        sessionActive = false
        interruptedSession = playing && owner != nil ? sessionID : nil
        if interruptedSession != nil { emit(["action": "interruptionPause"]) }
      case .ended:
        let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
          .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
        interrupted = false
        let resume = interruptedSession == sessionID && owner != nil &&
          options.contains(.shouldResume)
        interruptedSession = nil
        if resume {
          activateSession()
          if sessionActive { emit(["action": "interruptionResume"]) }
        }
      @unknown default:
        break
      }
    }
    center.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { note in
      guard
        let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
        let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
      else { return }
      // 拔耳机时 iOS 会把音频切到外放，听书场景里这是打扰，直接暂停。
      if reason == .oldDeviceUnavailable {
        interruptedSession = nil
        if playing { emit(["action": "pause"]) }
      }
    }
  }

  private static func emit(_ payload: [String: Any]) {
    guard let sink, let eventOwner = owner else { return }
    // 先固定事件身份再交给主线程，不能把旧命令重新标为新会话。
    var event = payload
    event["owner"] = eventOwner
    event["session"] = sessionID
    event["intent"] = intent
    let captured = event
    if Thread.isMainThread {
      sink(captured)
    } else {
      DispatchQueue.main.async { sink(captured) }
    }
  }

  static func setEventSink(_ events: FlutterEventSink?) {
    sink = events
  }
}
