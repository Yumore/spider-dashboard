import Flutter
import UIKit

/// `saveBackup` / `exportFanqieCapture` / `saveText` 在桌面上弹「另存为」,
/// iOS 没有等价的选择器,改为写临时文件再弹系统分享面板(存储到「文件」、
/// 发出去、AirDrop 都行)。Dart 侧拿到的是应用私有临时目录里的路径。
final class IosFilesBridge {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "fqapp/ios_files", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "saveFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let name = arguments["name"] as? String,
        let data = arguments["bytes"] as? FlutterStandardTypedData
      else {
        result(FlutterError(code: "BAD_ARGUMENT", message: "缺少文件内容", details: nil))
        return
      }
      presentShare(name: name, data: data.data, result: result)
    }
  }

  private static func presentShare(
    name: String, data: Data, result: @escaping FlutterResult
  ) {
    // 每次导出用独立子目录:同名的两次导出不会互相覆盖尚未分享完的文件。
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("fqapp-share", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(sanitize(name))
    do {
      try data.write(to: url, options: .atomic)
    } catch {
      result(FlutterError(code: "WRITE", message: error.localizedDescription, details: nil))
      return
    }
    DispatchQueue.main.async {
      guard let host = FanqieLoginBridge.topViewController() else {
        result(FlutterError(code: "NO_WINDOW", message: "窗口尚未就绪", details: nil))
        return
      }
      let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      if let popover = activity.popoverPresentationController,
        UIDevice.current.userInterfaceIdiom == .pad
      {
        popover.sourceView = host.view
        popover.sourceRect = CGRect(
          x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      // 分享面板的完成回调:Dart 侧约定「返回 nil = 取消」(见
      // desktop_platform.dart 的 _save)。取消要回 nil、失败要回错误,只有真正
      // 完成才把临时文件路径交回去——原实现无视完成标志,取消也报成功。
      var reported = false
      activity.completionWithItemsHandler = { _, completed, _, error in
        guard !reported else { return }
        reported = true
        if let error {
          result(FlutterError(code: "SHARE", message: error.localizedDescription, details: nil))
        } else if completed {
          result(url.path)
        } else {
          result(nil)
        }
      }
      host.present(activity, animated: true)
    }
  }

  private static func sanitize(_ name: String) -> String {
    let cleaned = name.replacingOccurrences(
      of: "[\\\\/:*?\"<>|]", with: "_", options: .regularExpression)
    let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "fqapp-export" : trimmed
  }
}
