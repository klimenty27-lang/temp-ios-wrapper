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
          var meta = document.querySelector('meta[name=viewport]');
          if (!meta) { meta = document.createElement('meta'); meta.name='viewport'; document.head.appendChild(meta); }
          meta.content = 'width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover';
          var style = document.createElement('style');
          style.innerHTML = `
            html, body { width:100% !important; max-width:100% !important; min-width:0 !important; overflow-x:hidden !important; -webkit-text-size-adjust:100% !important; }
            * { box-sizing:border-box; }
            @media (max-width: 600px) {
              body { font-size: 13px !important; }
              button, input, select, textarea { font-size: 13px !important; }
            }
          `;
          document.head.appendChild(style);
        })();
        """
        controller.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController = controller

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
        webView.isOpaque = true
        webView.backgroundColor = UIColor(red: 0.015, green: 0.055, blue: 0.10, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: startURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = view.bounds
    }
}
