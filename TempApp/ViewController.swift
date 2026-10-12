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
        controller.add(self, name: "tempNativeSettings")
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
        controller.addUserScript(WKUserScript(source: #"""
(function(){
  'use strict';
  function enhanceSettings(){
    const root=document.querySelector('.t64-settings');
    if(!root || root.querySelector('#temp-native-settings-v7'))return;
    const section=root.querySelector('#t64Mode')?.closest('section');
    if(!section)return;
    // This web dropdown only saved a preference, it did NOT change native Face ID.
    const preference=section.querySelector('#t64Mode');
    if(preference)preference.style.display='none';
    const note=section.querySelector('.t64-note');
    if(note)note.style.display='none';
    const button=document.createElement('button');
    button.id='temp-native-settings-v7';
    button.type='button';
    button.textContent='Вход и безопасность устройства';
    button.style.cssText='width:100%;padding:14px 12px;margin:12px 0 4px;font-size:16px;font-weight:700;border-radius:12px;background:linear-gradient(#ffb64e,#f37b17);color:#061e35;border:1px solid #ffc879;';
    button.addEventListener('click',function(){
      window.webkit?.messageHandlers?.tempNativeSettings?.postMessage({action:'open'});
    });
    section.appendChild(button);
  }
  let queued=false;
  const observer=new MutationObserver(function(){
    if(queued)return;
    queued=true;
    requestAnimationFrame(function(){queued=false;enhanceSettings();});
  });
  observer.observe(document.documentElement,{subtree:true,childList:true});
  enhanceSettings();
})();
"""#, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
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
        // The old separate settings button has been removed.
        navigationItem.rightBarButtonItem = nil
        // Native settings are now opened from the existing web Ещё → Настройки screen.
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

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "tempNativeSettings", unlocked else { return }
        guard let body = message.body as? [String: String], body["action"] == "open" else { return }
        openSettings()
    }

    @objc private func openSettings() {
        let settings = TempSettingsViewController()
        settings.selectedMode = mode
        settings.onSelect = { [weak self] value in self?.mode = value }
        let nav = UINavigationController(rootViewController: settings)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    // Only open allowed HTTPS navigation in the embedded app.
    func webView(_ webView:WKWebView, decidePolicyFor navigationAction:WKNavigationAction, decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
        guard let url=navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "https" || url.scheme == "about" { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }

    override var preferredStatusBarStyle:UIStatusBarStyle { .lightContent }
}
