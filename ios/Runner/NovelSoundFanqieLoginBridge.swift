import Flutter
import UIKit
import WebKit

/// 番茄书架采集的登录入口。
///
/// Android 有原生登录页,Windows/Linux 用 `webview_windows`;iOS 上两者都没有,
/// 这里用 `WKWebView` 打开官方登录页,用户完成登录后点「读取书架」,把
/// `fanqienovel.com` 的 cookie 交回 Dart(`FanqieLibraryCaptureService.collect`
/// 拿到 cookie 后由 Rust/Dart 侧直接请求采集接口)。
///
/// 与桌面版同一套约束:只允许官方域名(离开就拦下并提示),读取时要求存在
/// `sessionid` / `sessionid_ss` / `sid_tt` 之一且非空,整串不超过 12 KB。
///
/// 回调恰好一次:`login` 的 result 由实例持有,按钮取消、下滑关闭、`cancelLogin`
/// 与读取成功都走同一个 [finish]。`cancelLogin` 不丢弃持有的 result(否则 Dart
/// 的 `await login()` 会永远挂起),而是用 nil 把它正常收口。
final class FanqieLoginBridge: NSObject {
  private static let allowedHosts = [
    "fanqienovel.com", "snssdk.com", "bytedance.com", "zijieapi.com",
  ]
  private static let loginURL = URL(string: "https://fanqienovel.com/main/writer/login")!
  private static var active: FanqieLoginBridge?

  private let result: FlutterResult
  private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
  private let controller = UIViewController()
  private var finished = false

  private init(result: @escaping FlutterResult) {
    self.result = result
    super.init()
  }

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "fqapp/fanqie_account", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      // active 状态与所有 UIKit 操作都在主线程上串行处理,避免并发双开。
      DispatchQueue.main.async {
        switch call.method {
        case "login":
          let arguments = call.arguments as? [String: Any] ?? [:]
          login(dark: arguments["dark"] as? Bool ?? false, result: result)
        case "cancelLogin":
          active?.finish(nil)
          result(nil)
        case "clearSession":
          clearSession { result(nil) }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private static func login(dark: Bool, result: @escaping FlutterResult) {
    guard active == nil else {
      result(FlutterError(code: "BUSY", message: "登录窗口已打开", details: nil))
      return
    }
    guard let host = topViewController() else {
      result(FlutterError(code: "NO_WINDOW", message: "窗口尚未就绪", details: nil))
      return
    }
    let bridge = FanqieLoginBridge(result: result)
    active = bridge
    bridge.present(from: host, dark: dark)
  }

  private func present(from host: UIViewController, dark: Bool) {
    controller.view.backgroundColor = .systemBackground
    controller.title = "番茄登录"
    controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "取消", style: .plain, target: self, action: #selector(cancelTapped))
    controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "读取书架", style: .done, target: self, action: #selector(readTapped))

    webView.translatesAutoresizingMaskIntoConstraints = false
    webView.navigationDelegate = self
    webView.allowsBackForwardNavigationGestures = false
    controller.view.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor),
      webView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
    ])
    if dark {
      controller.overrideUserInterfaceStyle = .dark
      webView.overrideUserInterfaceStyle = .dark
    }
    let navigation = UINavigationController(rootViewController: controller)
    navigation.modalPresentationStyle = .pageSheet
    host.present(navigation, animated: true)
    // 下滑关闭(交互式)也必须把待决的 result 收口,否则 Dart 会一直等。
    // presentationController 在 present 返回后才存在,不能在 present 之前取。
    navigation.presentationController?.delegate = self
    webView.load(URLRequest(url: Self.loginURL))
  }

  @objc private func cancelTapped() {
    finish(nil)
  }

  @objc private func readTapped() {
    // 先等一次 JS 执行,确保 cookie 已写进 WKWebsiteDataStore 再读取。
    webView.evaluateJavaScript("document.title") { [weak self] _, _ in
      self?.readCookies()
    }
  }

  private func readCookies() {
    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
      guard let self else { return }
      // 用户在读取途中点了取消:不再弹提示,也不再交回结果。
      guard !self.finished else { return }
      let scoped = cookies.filter { cookie in
        let domain = cookie.domain.hasPrefix(".")
          ? String(cookie.domain.dropFirst()) : cookie.domain
        return domain == "fanqienovel.com" || domain.hasSuffix(".fanqienovel.com")
      }
      let names = ["sessionid", "sessionid_ss", "sid_tt"]
      let hasLogin = scoped.contains { cookie in
        names.contains(cookie.name) && !cookie.value.isEmpty
      }
      guard hasLogin else {
        DispatchQueue.main.async { self.alert("尚未取得登录态", "请先在官方页面完成登录与验证,再点「读取书架」。") }
        return
      }
      let value = scoped.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
      guard value.utf8.count <= 12 * 1024 else {
        DispatchQueue.main.async { self.alert("登录态过大", "读取失败,请重试。") }
        return
      }
      DispatchQueue.main.async { self.finish(value) }
    }
  }

  private func alert(_ title: String, _ message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "好", style: .default))
    controller.present(alert, animated: true)
  }

  /// 关闭窗口并把 result 恰好交回一次;[value] 为 nil 表示取消。
  ///
  /// [active] 要等关闭动画结束再清:若在 dismiss 还在跑时就放行下一次 login,
  /// 新的 present 会落在还没消失的旧窗口上,UIKit 可能拒绝,Dart 的 await 悬空。
  private func finish(_ value: String?) {
    guard !finished else { return }
    finished = true
    let complete = {
      if Self.active === self { Self.active = nil }
      self.result(value)
    }
    if let navigation = controller.navigationController,
      navigation.presentingViewController != nil
    {
      navigation.dismiss(animated: true, completion: complete)
    } else {
      // 交互式下滑已经关掉了窗口:直接交回结果,不再重复 dismiss。
      complete()
    }
  }

  private static func clearSession(completion: @escaping () -> Void) {
    let store = WKWebsiteDataStore.default()
    store.httpCookieStore.getAllCookies { cookies in
      let targets = cookies.filter { cookie in
        let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
        return domain == "fanqienovel.com" || domain.hasSuffix(".fanqienovel.com")
      }
      let group = DispatchGroup()
      for cookie in targets {
        group.enter()
        store.httpCookieStore.delete(cookie) { group.leave() }
      }
      group.notify(queue: .main) { completion() }
    }
  }

  static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
      ?? scene?.windows.first?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

extension FanqieLoginBridge: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    guard let url = navigationAction.request.url else {
      decisionHandler(.cancel)
      return
    }
    if url.scheme != "https" || url.user != nil || url.password != nil {
      decisionHandler(.cancel)
      return
    }
    let host = url.host ?? ""
    let allowed = FanqieLoginBridge.allowedHosts.contains { entry in
      host == entry || host.hasSuffix(".\(entry)")
    }
    if allowed {
      decisionHandler(.allow)
    } else {
      decisionHandler(.cancel)
      alert("已拦截跳转", "请留在番茄官方登录页面完成登录。")
    }
  }
}

extension FanqieLoginBridge: UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    // 下滑关闭:login 必须收到 nil,而不是无限等待。
    finish(nil)
  }
}
