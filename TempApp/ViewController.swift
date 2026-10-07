import UIKit
import WebKit

final class ViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private let startURL = URL(string: "https://temp-kz.pages.dev")!

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true

        let controller = WKUserContentController()
        let js = """
        (function() {
          let meta = document.querySelector('meta[name="viewport"]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
          }
          meta.content = 'width=device-width, initial-scale=1, viewport-fit=cover';

          const style = document.createElement('style');
          style.id = 'temp-ios-adaptive-v3';
          style.textContent = `
            :root {
              --temp-safe-top: env(safe-area-inset-top, 0px);
              --temp-safe-right: env(safe-area-inset-right, 0px);
              --temp-safe-bottom: env(safe-area-inset-bottom, 0px);
              --temp-safe-left: env(safe-area-inset-left, 0px);
            }
            html {
              width: 100% !important;
              min-height: 100% !important;
              background: #031426 !important;
              -webkit-text-size-adjust: 100% !important;
            }
            body {
              width: 100% !important;
              min-width: 0 !important;
              max-width: 100% !important;
              min-height: 100dvh !important;
              margin: 0 !important;
              overflow-x: hidden !important;
              background: #031426 !important;
              padding-left: var(--temp-safe-left) !important;
              padding-right: var(--temp-safe-right) !important;
            }
            *, *::before, *::after { box-sizing: border-box !important; }
            img, video, canvas, svg { max-width: 100%; }
            input, select, textarea, button { max-width: 100%; }
            @media (max-width: 430px) {
              body { font-size: 13px !important; }
              button, input, select, textarea { font-size: 13px !important; }
            }
            @media (max-width: 380px) {
              body { font-size: 12px !important; }
              button, input, select, textarea { font-size: 12px !important; }
            }
          `;
          document.head.appendChild(style);

          // Keep focused fields visible when the iPhone keyboard opens.
          document.addEventListener('focusin', function(e) {
            if (e.target && /INPUT|TEXTAREA|SELECT/.test(e.target.tagName)) {
              setTimeout(() => {
                e.target.scrollIntoView({behavior:'smooth', block:'center', inline:'nearest'});
              }, 350);
            }
          });
        })();
        """
        controller.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController = controller

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 3/255, green: 20/255, blue: 38/255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor

        let container = UIView()
        container.backgroundColor = webView.backgroundColor
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: startURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
