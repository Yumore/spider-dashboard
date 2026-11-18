import UIKit
import Flutter
import UserNotifications
import AVFoundation
import MediaPlayer
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var nowPlayingChannel: FlutterMethodChannel?
  private var pendingDeepLink: String?
  private var remoteCommandsConfigured = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.guomu.huangguo.update-check",
      earliestBeginInSeconds: NSNumber(value: 24 * 60 * 60)
    )
    UNUserNotificationCenter.current().delegate = self
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .moviePlayback,
        options: [.allowAirPlay, .allowBluetoothA2DP]
      )
    } catch {
      // 后台音频配置失败不应阻断应用启动。
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.guomu.huangguo/share",
        binaryMessenger: controller.binaryMessenger
      )
      let linkChannel = FlutterMethodChannel(
        name: "com.guomu.huangguo/deeplink",
        binaryMessenger: controller.binaryMessenger
      )
      let nowPlayingChannel = FlutterMethodChannel(
        name: "com.guomu.huangguo/nowplaying",
        binaryMessenger: controller.binaryMessenger
      )
      self.deepLinkChannel = linkChannel
      self.nowPlayingChannel = nowPlayingChannel
      configureRemoteCommands()
      nowPlayingChannel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "update":
          guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "bad_args", message: "缺少播放信息", details: nil))
            return
          }
          self?.updateNowPlaying(args)
          result(nil)
        case "clear":
          self?.clearNowPlaying()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      linkChannel.setMethodCallHandler { [weak self] call, result in
        if call.method == "getInitialLink" {
          result(self?.pendingDeepLink)
          self?.pendingDeepLink = nil
          return
        }
        result(FlutterMethodNotImplemented)
      }

      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "share" else {
          result(FlutterMethodNotImplemented)
          return
        }

        let args = call.arguments as? [String: Any]
        let title = args?["title"] as? String ?? ""
        let text = args?["text"] as? String ?? ""
        let url = args?["url"] as? String ?? ""
        let shareText = [title, text, url]
          .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
          .joined(separator: "\n")

        let activity = UIActivityViewController(
          activityItems: [shareText],
          applicationActivities: nil
        )
        if let popover = activity.popoverPresentationController {
          popover.sourceView = controller.view
          popover.sourceRect = CGRect(
            x: controller.view.bounds.midX,
            y: controller.view.bounds.maxY - 40,
            width: 1,
            height: 1
          )
        }
        self?.window?.rootViewController?.present(activity, animated: true) {
          result(true)
        }
      }
    }

    if let url = launchOptions?[.url] as? URL, url.scheme == "guomu" {
      pendingDeepLink = url.absoluteString
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureRemoteCommands() {
    guard !remoteCommandsConfigured else { return }
    remoteCommandsConfigured = true
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.isEnabled = true
    center.pauseCommand.isEnabled = true
    center.togglePlayPauseCommand.isEnabled = true
    center.changePlaybackPositionCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] _ in
      self?.nowPlayingChannel?.invokeMethod("play", arguments: nil)
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      self?.nowPlayingChannel?.invokeMethod("pause", arguments: nil)
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.nowPlayingChannel?.invokeMethod("toggle", arguments: nil)
      return .success
    }
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let seekEvent = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.nowPlayingChannel?.invokeMethod("seekTo", arguments: seekEvent.positionTime)
      return .success
    }
  }

  private func updateNowPlaying(_ args: [String: Any]) {
    let title = args["title"] as? String ?? "果幕短剧"
    let subtitle = args["subtitle"] as? String ?? "黄果短剧"
    let position = (args["positionMs"] as? NSNumber)?.doubleValue ?? 0
    let duration = (args["durationMs"] as? NSNumber)?.doubleValue ?? 0
    let speed = max((args["speed"] as? NSNumber)?.doubleValue ?? 1, 0.1)
    let isPlaying = args["isPlaying"] as? Bool ?? false
    let deepLink = args["deepLink"] as? String ?? "guomu://"
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: title,
      MPMediaItemPropertyArtist: subtitle,
      MPMediaItemPropertyAlbumTitle: "果幕 · 黄果短剧",
      MPNowPlayingInfoPropertyElapsedPlaybackTime: position / 1000,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? speed : 0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: speed,
      MPNowPlayingInfoPropertyExternalContentIdentifier: deepLink,
      MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
    ]
    if duration > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = duration / 1000
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    UIApplication.shared.beginReceivingRemoteControlEvents()
    do {
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      // 音频会话保持系统当前状态。
    }
  }

  private func clearNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped
    UIApplication.shared.endReceivingRemoteControlEvents()
    do {
      try AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
    } catch {
      // 其他音频恢复由系统处理。
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "guomu" {
      pendingDeepLink = url.absoluteString
      deepLinkChannel?.invokeMethod("link", arguments: url.absoluteString)
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
