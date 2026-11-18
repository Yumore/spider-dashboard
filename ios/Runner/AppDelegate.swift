import AVFoundation
import Flutter
import MediaPlayer
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var guomuEntryChannel: FlutterMethodChannel?
  private var guomuAudioChannel: FlutterMethodChannel?
  private var nowPlayingChannel: FlutterMethodChannel?
  private var pendingDeepLink: String?
  private var previousAudioSession: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?
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

    if let controller = window?.rootViewController as? FlutterViewController {
      let shareChannel = FlutterMethodChannel(
        name: "com.guomu.huangguo/share",
        binaryMessenger: controller.binaryMessenger
      )
      let linkChannel = FlutterMethodChannel(
        name: "com.guomu.huangguo/deeplink",
        binaryMessenger: controller.binaryMessenger
      )
      let entryChannel = FlutterMethodChannel(
        name: "com.yumore.dashboard/guomu-entry",
        binaryMessenger: controller.binaryMessenger
      )
      let audioChannel = FlutterMethodChannel(
        name: "com.guomu.huangguo/audio",
        binaryMessenger: controller.binaryMessenger
      )
      let nowPlayingChannel = FlutterMethodChannel(
        name: "com.guomu.huangguo/nowplaying",
        binaryMessenger: controller.binaryMessenger
      )
      deepLinkChannel = linkChannel
      guomuEntryChannel = entryChannel
      guomuAudioChannel = audioChannel
      self.nowPlayingChannel = nowPlayingChannel
      configureRemoteCommands()
      linkChannel.setMethodCallHandler { [weak self] call, result in
        if call.method == "consumeInitialLink" {
          self?.pendingDeepLink = nil
          result(nil)
          return
        }
        guard call.method == "getInitialLink" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self?.pendingDeepLink)
        self?.pendingDeepLink = nil
      }
      entryChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "getInitialLink" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self?.pendingDeepLink)
      }
      audioChannel.setMethodCallHandler { [weak self] call, result in
        let session = AVAudioSession.sharedInstance()
        do {
          switch call.method {
          case "activate":
            if self?.previousAudioSession == nil {
              self?.previousAudioSession = (
                session.category,
                session.mode,
                session.categoryOptions
              )
            }
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
            result(nil)
          case "deactivate":
            if let previous = self?.previousAudioSession {
              try session.setCategory(
                previous.0,
                mode: previous.1,
                options: previous.2
              )
              try session.setActive(false, options: .notifyOthersOnDeactivation)
              self?.previousAudioSession = nil
            }
            result(nil)
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(
            code: "AUDIO_SESSION",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
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
      shareChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "share" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let controller = self?.window?.rootViewController else {
          result(false)
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
        controller.present(activity, animated: true) {
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
    // The embedded page owns audio-session activation and restoration.
    if previousAudioSession != nil {
      try? AVAudioSession.sharedInstance().setActive(true)
    }
  }

  private func clearNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped
    UIApplication.shared.endReceivingRemoteControlEvents()
    // Keep session restoration in the Guomu page lifecycle channel.
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.scheme == "guomu" else {
      return super.application(app, open: url, options: options)
    }
    pendingDeepLink = url.absoluteString
    deepLinkChannel?.invokeMethod("link", arguments: url.absoluteString)
    guomuEntryChannel?.invokeMethod("open", arguments: url.absoluteString)
    return true
  }
}
