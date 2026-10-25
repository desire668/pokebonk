import UIKit
import WebKit

/// 纯壳：整个屏幕就是一个 WKWebView，游戏自己的移动端触屏 UI 原样工作。
final class GameViewController: UIViewController {

    private static let fallbackHomeURL = "https://pokebonk.com/"

    private var webView: WKWebView!

    private let errorContainer = UIView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private var homeURL: URL {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "PokeBonkHomeURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = raw, !raw.isEmpty, let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: Self.fallbackHomeURL)!
    }

    // MARK: - 外观

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.102, green: 0.086, blue: 0.188, alpha: 1.0)
        setupWebView()
        setupErrorView()
        loadGame()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = view.bounds
        errorContainer.frame = view.bounds
        errorLabel.frame = CGRect(x: 40,
                                  y: view.bounds.midY - 60,
                                  width: view.bounds.width - 80,
                                  height: 80)
        retryButton.frame = CGRect(x: view.bounds.midX - 70,
                                   y: view.bounds.midY + 20,
                                   width: 140,
                                   height: 44)
    }

    // MARK: - WebView

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // 用默认持久化存储，游戏进度（本地存档）才不会丢
        config.websiteDataStore = .default()

        // 解锁 WebAudio：首次触摸时把 suspended 的 AudioContext 全部 resume
        config.userContentController.addUserScript(
            WKUserScript(source: AudioUnlock.scriptSource,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: true)
        )

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.isOpaque = true
        wv.backgroundColor = UIColor(red: 0.102, green: 0.086, blue: 0.188, alpha: 1.0)
        wv.allowsLinkPreview = false
        // 不覆盖 UA，让站点按 iOS Safari 提供移动端触屏版本
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        wv.scrollView.minimumZoomScale = 1.0
        wv.scrollView.maximumZoomScale = 1.0
        wv.scrollView.pinchGestureRecognizer?.isEnabled = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.allowsBackForwardNavigationGestures = false
        view.addSubview(wv)
        webView = wv
    }

    @objc private func loadGame() {
        errorContainer.isHidden = true
        let request = URLRequest(url: homeURL,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 30)
        webView.load(request)
    }

    // MARK: - 加载失败提示

    private func setupErrorView() {
        errorContainer.backgroundColor = UIColor(white: 0.05, alpha: 0.92)
        errorContainer.isHidden = true
        view.addSubview(errorContainer)

        errorLabel.textColor = .white
        errorLabel.font = .systemFont(ofSize: 16, weight: .medium)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorContainer.addSubview(errorLabel)

        retryButton.setTitle("重新加载", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        retryButton.addTarget(self, action: #selector(loadGame), for: .touchUpInside)
        errorContainer.addSubview(retryButton)
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorContainer.isHidden = false
        view.bringSubviewToFront(errorContainer)
    }
}

// MARK: - WKNavigationDelegate / WKUIDelegate

extension GameViewController: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorContainer.isHidden = true
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        showError("加载失败：\(error.localizedDescription)\n请检查网络后重试。")
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        showError("无法打开 PokéBonk：\(error.localizedDescription)\n请检查网络后重试。")
    }

    // window.open / target=_blank 也留在同一个 WebView 里打开
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
