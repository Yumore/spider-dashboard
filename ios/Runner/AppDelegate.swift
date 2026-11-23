import AVFoundation
import ActivityKit
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
  private var liveActivityChannel: FlutterMethodChannel?
  private var pendingDeepLink: String?
  private var previousAudioSession: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?

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
      let messenger = controller.binaryMessenger
      SecureKeyBridge.register(messenger: messenger)
      FanqieLoginBridge.register(messenger: messenger)
      IosFilesBridge.register(messenger: messenger)
      SystemTtsBridge.register(messenger: messenger)
      AudioSessionBridge.register(messenger: messenger)
      AudioSessionBridge.guomuRemoteCommandHandler = { [weak self] action, position in
        switch action {
        case "play": self?.nowPlayingChannel?.invokeMethod("play", arguments: nil)
        case "pause": self?.nowPlayingChannel?.invokeMethod("pause", arguments: nil)
        case "playPause": self?.nowPlayingChannel?.invokeMethod("toggle", arguments: nil)
        case "seek": self?.nowPlayingChannel?.invokeMethod("seekTo", arguments: position)
        default: break
        }
      }
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
      let liveActivityChannel = FlutterMethodChannel(
        name: "com.guomu.huangguo/liveactivity",
        binaryMessenger: controller.binaryMessenger
      )
      self.liveActivityChannel = liveActivityChannel
      liveActivityChannel.setMethodCallHandler { call, result in
        // Match the App Group shared by Runner and GuomuWidget in this host app.
        let groupId = "group.com.nsapp.dashboard.guomu"
        switch call.method {
        case "isAvailable":
          guard #available(iOS 16.1, *),
                FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: groupId
                ) != nil,
                let plugins = Bundle.main.builtInPlugInsURL,
                let extensions = try? FileManager.default.contentsOfDirectory(
                  at: plugins,
                  includingPropertiesForKeys: nil
                ),
                extensions.contains(where: {
                  $0.lastPathComponent == "GuomuWidget.appex"
                }) else {
            result(false)
            return
          }
          result(ActivityAuthorizationInfo().areActivitiesEnabled)
        case "prepareCover":
          guard let args = call.arguments as? [String: Any],
                let bytes = args["bytes"] as? FlutterStandardTypedData,
                let videoId = args["videoId"] as? Int,
                let root = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: groupId
                ),
                let image = UIImage(data: bytes.data),
                image.size.width > 0,
                image.size.height > 0 else {
            result("")
            return
          }
          do {
            let directory = root.appendingPathComponent(
              "GuomuActivityCovers",
              isDirectory: true
            )
            try FileManager.default.createDirectory(
              at: directory,
              withIntermediateDirectories: true
            )
            let scale = min(1, 128 / max(image.size.width, image.size.height))
            let size = CGSize(
              width: image.size.width * scale,
              height: image.size.height * scale
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { _ in
              image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let jpeg = thumbnail.jpegData(compressionQuality: 0.8) else {
              result("")
              return
            }
            let destination = directory.appendingPathComponent("cover-\(videoId).jpg")
            try jpeg.write(to: destination, options: .atomic)
            result(destination.path)
          } catch {
            result("")
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      deepLinkChannel = linkChannel
      guomuEntryChannel = entryChannel
      guomuAudioChannel = audioChannel
      self.nowPlayingChannel = nowPlayingChannel
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

  private func updateNowPlaying(_ args: [String: Any]) {
    guard !AudioSessionBridge.hasActiveOwner else { return }
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
    AudioSessionBridge.setGuomuCommandAvailability(true)
    UIApplication.shared.beginReceivingRemoteControlEvents()
    // The embedded page owns audio-session activation and restoration.
    if previousAudioSession != nil {
      try? AVAudioSession.sharedInstance().setActive(true)
    }
  }

  private func clearNowPlaying() {
    guard !AudioSessionBridge.hasActiveOwner else { return }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped
    UIApplication.shared.endReceivingRemoteControlEvents()
    AudioSessionBridge.setGuomuCommandAvailability(false)
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
