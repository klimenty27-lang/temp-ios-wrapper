import UIKit
import WebKit
import LocalAuthentication

final class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private let site = URL(string: "https://temp-kz.pages.dev")!
    private var unlocked = false
    private var lockOverlay: UIView?
    private var hasLoaded = false
    private var appObserver: NSObjectProtocol?
    private let background = UIColor(red: 3/255, green: 20/255, blue: 38/255, alpha: 1)

    // "biometric": biometrics first, with device passcode fallback.
    // "passcode": device passcode, NOT the TEMP account password.
    // "none": keep the existing authenticated web session.
    private var mode: String {
        get { UserDefaults.standard.string(forKey: "temp_device_lock_mode") ?? "biometric" }
        set { UserDefaults.standard.set(newValue, forKey: "temp_device_lock_mode") }
    }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: """
          (function(){
            const meta = document.querySelector('meta[name="viewport"]') || document.createElement('meta');
            meta.name='viewport';
            meta.content='width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover';
            if(!meta.parentNode) document.head.appendChild(meta);
            const style = document.createElement('style');
            style.textContent = `
              html { width:100%; overflow-x:hidden; -webkit-text-size-adjust:100%; background:#031426; }
              body { max-width:100%; min-width:0; overflow-x:hidden; margin:0; background:#031426; }
              input,select,textarea { font-size:16px !important; }
              *,*::before,*::after { box-sizing:border-box; }
            `;
            document.head.appendChild(style);
          })();
          """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        controller.add(TempWeakScriptHandler(self), name: "tempNativeSettings")
        controller.addUserScript(WKUserScript(source: TempMobileScripts.loginMemory,
                                             injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: TempMobileScripts.settingsEntry,
                                             injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController = controller
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = background
        webView.scrollView.backgroundColor = background
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        let host = UIView()
        host.backgroundColor = background
        host.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            webView.topAnchor.constraint(equalTo: host.topAnchor),
            webView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        view = host
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationItem.rightBarButtonItem = nil
        showLock()
        appObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.lockIfRequired() }
        authenticate()
    }

    deinit {
        if let appObserver = appObserver { NotificationCenter.default.removeObserver(appObserver) }
    }

    private func showLock() {
        guard lockOverlay == nil else { return }
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = background
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "ТЕМП"
        title.textColor = .white
        title.font = .systemFont(ofSize:32,weight:.bold)
        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.text = "Подтвердите вход на устройстве"
        hint.textColor = .lightGray
        hint.font = .systemFont(ofSize:15)
        let button = UIButton(type:.system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Разблокировать", for:.normal)
        button.titleLabel?.font = .systemFont(ofSize:17,weight:.semibold)
        button.tintColor = UIColor(red:1,green:0.49,blue:0.12,alpha:1)
        button.addTarget(self, action:#selector(authenticate), for:.touchUpInside)
        overlay.addSubview(title); overlay.addSubview(hint); overlay.addSubview(button)
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo:view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo:view.bottomAnchor),
            title.centerXAnchor.constraint(equalTo:overlay.centerXAnchor),
            title.centerYAnchor.constraint(equalTo:overlay.centerYAnchor,constant:-70),
            hint.centerXAnchor.constraint(equalTo:overlay.centerXAnchor),
            hint.topAnchor.constraint(equalTo:title.bottomAnchor,constant:14),
            button.centerXAnchor.constraint(equalTo:overlay.centerXAnchor),
            button.topAnchor.constraint(equalTo:hint.bottomAnchor,constant:24)
        ])
        lockOverlay = overlay
    }

    private func lockIfRequired() {
        if mode == "none" { return }
        unlocked = false
        if presentedViewController is UINavigationController {
            dismiss(animated: false)
        }
        showLock()
        authenticate()
    }

    @objc private func authenticate() {
        if mode == "none" { didUnlock(); return }
        let context = LAContext()
        context.localizedFallbackTitle = "Код-пароль iPhone"
        let policy: LAPolicy = mode == "passcode" ? .deviceOwnerAuthentication : .deviceOwnerAuthentication
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error:&error) else {
            showAuthError("Настройте Face ID или код-пароль в настройках iPhone.")
            return
        }
        context.evaluatePolicy(policy, localizedReason:"Открыть приложение ТЕМП") { [weak self] success, error in
            DispatchQueue.main.async {
                if success { self?.didUnlock() }
                else if let error = error as NSError?, error.code != LAError.userCancel.rawValue {
                    self?.showAuthError("Не удалось подтвердить вход. Попробуйте ещё раз.")
                }
            }
        }
    }

    private func didUnlock() {
        unlocked = true
        lockOverlay?.removeFromSuperview()
        lockOverlay = nil
        if !hasLoaded {
            hasLoaded = true
            webView.load(URLRequest(url:site, cachePolicy:.reloadRevalidatingCacheData))
        }
    }

    private func showAuthError(_ message:String) {
        let alert = UIAlertController(title:"ТЕМП",message:message,preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Понятно",style:.default))
        present(alert,animated:true)
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // This bridge exposes only settings, never credentials, arbitrary JS or navigation.
        guard message.name == "tempNativeSettings", unlocked,
              UIApplication.shared.applicationState == .active,
              message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https",
              message.frameInfo.securityOrigin.host == site.host,
              let data = message.body as? [String: Any],
              data["action"] as? String == "open",
              presentedViewController == nil else { return }
        let version = data["webVersion"] as? String ?? ""
        let login = data["savedLogin"] as? String ?? ""
        openSettings(webVersion: version, savedLogin: login,
                     rememberLogin: data["rememberLogin"] as? Bool ?? true)
    }

    private func openSettings(webVersion: String, savedLogin: String, rememberLogin: Bool) {
        let settings = TempSettingsViewController()
        settings.selectedMode = mode
        settings.webVersion = versionLabel(webVersion)
        settings.savedLogin = String(savedLogin.prefix(320))
        settings.rememberLogin = rememberLogin
        settings.onSelect = { [weak self] value in self?.mode = value }
        settings.onRememberLogin = { [weak self] enabled in
            self?.webView.evaluateJavaScript("window.TempLoginMemory?.setEnabled(" + (enabled ? "true" : "false") + ");", completionHandler: nil)
        }
        settings.onForgetLogin = { [weak self] in
            self?.webView.evaluateJavaScript("window.TempLoginMemory?.forget();", completionHandler: nil)
        }
        let nav = UINavigationController(rootViewController: settings)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func versionLabel(_ value: String) -> String {
        guard value.range(of: "^[0-9]+(\\.[0-9]+){1,3}$", options: .regularExpression) != nil else { return "не определена" }
        return String(value.prefix(32))
    }

    // Only open allowed HTTPS navigation in the embedded app.
    func webView(_ webView:WKWebView, decidePolicyFor navigationAction:WKNavigationAction, decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
        guard let url=navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "https" || url.scheme == "about" { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }

    override var preferredStatusBarStyle:UIStatusBarStyle { .lightContent }
}
