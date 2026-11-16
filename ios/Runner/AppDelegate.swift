import AVFoundation
import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var guomuEntryChannel: FlutterMethodChannel?
  private var guomuAudioChannel: FlutterMethodChannel?
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
      deepLinkChannel = linkChannel
      guomuEntryChannel = entryChannel
      guomuAudioChannel = audioChannel
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
