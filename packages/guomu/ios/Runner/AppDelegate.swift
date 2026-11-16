import UIKit
import Flutter
import UserNotifications
import AVFoundation
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var pendingDeepLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    UNUserNotificationCenter.current().delegate = self
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
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
      self.deepLinkChannel = linkChannel
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
