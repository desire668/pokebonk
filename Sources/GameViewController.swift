import UIKit
import WebKit

final class GameViewController: UIViewController {

    private static let fallbackHomeURL = "https://pokebonk.app/zh-cn/"
    /// 桌面版 UA：让游戏走「WASD + 鼠标转视角」的桌端输入模型，正好对应左摇杆 / 右视角区。
    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    // MARK: - 视图

    private var webView: WKWebView!
    private let joystick = JoystickView()
    private let lookPad = LookPadView()
    private let toggleButton = UIButton(type: .custom)
    private let settingsButton = UIButton(type: .custom)
    private var actionButtons: [ActionButton] = []

    private let errorContainer = UIView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    // MARK: - 状态

    private var controlsEnabled = true
    private var pageReady = false
    private var pendingMove = CGPoint.zero
    private var moveDirty = false
    private var pendingLook = CGPoint.zero
    private var displayLink: CADisplayLink?

    private var sensitivity: Float {
        get { UserDefaults.standard.object(forKey: "pb.sensitivity") as? Float ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: "pb.sensitivity") }
    }
    private var invertY: Bool {
        get { UserDefaults.standard.bool(forKey: "pb.invertY") }
        set { UserDefaults.standard.set(newValue, forKey: "pb.invertY") }
    }
    private var lookMode: String {
        get { UserDefaults.standard.string(forKey: "pb.lookMode") ?? "mouse" }
        set { UserDefaults.standard.set(newValue, forKey: "pb.lookMode") }
    }

    private var homeURL: URL {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "PokeBonkHomeURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = raw, !raw.isEmpty, let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: Self.fallbackHomeURL)!
    }

    // MARK: - 生命周期

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.102, green: 0.086, blue: 0.188, alpha: 1.0)

        setupWebView()
        setupControls()
        setupErrorView()
        loadGame()

        let link = CADisplayLink(target: self, selector: #selector(flushInput))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    deinit { displayLink?.invalidate() }

    // MARK: - WebView

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let userScript = WKUserScript(source: InputBridge.scriptSource,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = Self.desktopUserAgent
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 0.102, green: 0.086, blue: 0.188, alpha: 1.0)
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        wv.scrollView.minimumZoomScale = 1.0
        wv.scrollView.maximumZoomScale = 1.0
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.allowsBackForwardNavigationGestures = false
        wv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wv)
        webView = wv
    }

    @objc private func loadGame() {
        pageReady = false
        errorContainer.isHidden = true
        webView.load(URLRequest(url: homeURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30))
    }

    // MARK: - 控件

    private func setupControls() {
        joystick.delegate = self
        lookPad.delegate = self
        view.addSubview(lookPad)
        view.addSubview(joystick)

        let specs: [(String, String)] = [
            ("KeyR", "大招"),
            ("KeyE", "互动"),
            ("Space", "跳跃"),
            ("ShiftLeft", "滑行")
        ]
        for (code, title) in specs {
            let button = ActionButton(code: code, title: title)
            button.addTarget(self, action: #selector(actionButtonDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(actionButtonUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            view.addSubview(button)
            actionButtons.append(button)
        }

        configureCornerButton(toggleButton, title: "⌾")
        toggleButton.addTarget(self, action: #selector(toggleControls), for: .touchUpInside)
        view.addSubview(toggleButton)

        configureCornerButton(settingsButton, title: "⚙")
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)
    }

    private func configureCornerButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor(white: 1.0, alpha: 0.85), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.backgroundColor = UIColor(white: 0.06, alpha: 0.35)
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 1.5
        button.layer.borderColor = UIColor(white: 1.0, alpha: 0.35).cgColor
    }

    private func layoutGameUI() {
        let b = view.bounds
        let safe = view.safeAreaInsets
        webView.frame = b

        let joystickWidth = b.width * 0.46
        let joystickHeight = b.height * 0.78
        joystick.frame = CGRect(x: 0, y: b.height - joystickHeight, width: joystickWidth, height: joystickHeight)

        let lookWidth = b.width * 0.54
        lookPad.frame = CGRect(x: b.width - lookWidth, y: 0, width: lookWidth, height: b.height)

        let size = max(56, min(84, min(b.width, b.height) * 0.17))
        let gap: CGFloat = 10
        let rightEdge = b.width - safe.right - 22
        let bottomEdge = b.height - safe.bottom - 22
        let origins: [CGPoint] = [
            CGPoint(x: rightEdge - size, y: bottomEdge - size * 2 - gap),            // 大招
            CGPoint(x: rightEdge - size * 2 - gap, y: bottomEdge - size * 2 - gap),  // 互动
            CGPoint(x: rightEdge - size, y: bottomEdge - size),                      // 跳跃
            CGPoint(x: rightEdge - size * 2 - gap, y: bottomEdge - size)             // 滑行
        ]
        for (index, button) in actionButtons.enumerated() where index < origins.count {
            button.frame = CGRect(origin: origins[index], size: CGSize(width: size, height: size))
        }

        toggleButton.frame = CGRect(x: safe.left + 14, y: safe.top + 14, width: 40, height: 40)
        settingsButton.frame = CGRect(x: safe.left + 62, y: safe.top + 14, width: 40, height: 40)
    }

    // MARK: - 输入下发

    @objc private func flushInput() {
        guard pageReady, controlsEnabled else { return }

        if pendingLook != .zero {
            let dx = Double(pendingLook.x)
            let dy = Double(pendingLook.y)
            pendingLook = .zero
            runJS(String(format: "__pb.look(%f,%f);", dx, dy))
        }
        if moveDirty {
            moveDirty = false
            runJS(String(format: "__pb.move(%f,%f);", Double(pendingMove.x), Double(pendingMove.y)))
        }
    }

    private func runJS(_ script: String) {
        guard pageReady else { return }
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func applySettingsToJS() {
        runJS(String(format: "__pb.setSensitivity(%f);__pb.setInvertY(%@);__pb.setLookMode('%@');",
                     Double(sensitivity), invertY ? "true" : "false", lookMode))
    }

    // MARK: - 动作

    @objc private func actionButtonDown(_ sender: ActionButton) {
        runJS(String(format: "__pb.setKey('%@',true);", sender.code))
    }

    @objc private func actionButtonUp(_ sender: ActionButton) {
        runJS(String(format: "__pb.setKey('%@',false);", sender.code))
    }

    @objc private func toggleControls() {
        controlsEnabled.toggle()
        joystick.isHidden = !controlsEnabled
        lookPad.isHidden = !controlsEnabled
        actionButtons.forEach { $0.isHidden = !controlsEnabled }
        if !controlsEnabled {
            runJS("__pb.reset();")
            pendingLook = .zero
            pendingMove = .zero
            moveDirty = false
        }
        toggleButton.setTitle(controlsEnabled ? "⌾" : "○", for: .normal)
    }

    @objc private func openSettings() {
        let vc = SettingsViewController(sensitivity: sensitivity, invertY: invertY, lookMode: lookMode)
        vc.onChange = { [weak self] sensitivity, invertY, lookMode in
            self?.sensitivity = sensitivity
            self?.invertY = invertY
            self?.lookMode = lookMode
            self?.applySettingsToJS()
        }
        vc.onReload = { [weak self] in self?.loadGame() }
        vc.modalPresentationStyle = .popover
        vc.popoverPresentationController?.sourceView = settingsButton
        vc.popoverPresentationController?.permittedArrowDirections = .up
        vc.preferredContentSize = CGSize(width: 320, height: 300)
        present(vc, animated: true)
    }

    // MARK: - 错误页

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutGameUI()
        errorContainer.frame = view.bounds
        errorLabel.frame = CGRect(x: 40, y: view.bounds.midY - 60, width: view.bounds.width - 80, height: 80)
        retryButton.frame = CGRect(x: view.bounds.midX - 70, y: view.bounds.midY + 20, width: 140, height: 44)
    }
}

// MARK: - JoystickViewDelegate

extension GameViewController: JoystickViewDelegate {
    func joystick(_ sender: JoystickView, didChange vector: CGVector) {
        pendingMove = CGPoint(x: vector.dx, y: vector.dy)
        moveDirty = true
    }

    func joystickDidRelease(_ sender: JoystickView) {
        pendingMove = .zero
        moveDirty = true
    }
}

// MARK: - LookPadViewDelegate

extension GameViewController: LookPadViewDelegate {
    func lookPadDidBegin(_ sender: LookPadView) {
        // 开始拖动时强制尝试一次指针锁定，进对局后通常就能锁上
        runJS("__pb.forceLock();")
    }

    func lookPad(_ sender: LookPadView, didDrag delta: CGVector) {
        pendingLook.x += delta.dx
        pendingLook.y += delta.dy
    }

    func lookPadDidEnd(_ sender: LookPadView) {
        runJS("__pb.lookEnd();")
    }
}

// MARK: - WKNavigationDelegate / WKUIDelegate

extension GameViewController: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        errorContainer.isHidden = true
        applySettingsToJS()
        runJS("__pb.ready();")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        pageReady = true
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        showError("加载失败：\(error.localizedDescription)\n请检查网络后重试。")
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        let code = (error as NSError).code
        if code == NSURLErrorCancelled { return }
        showError("无法打开 PokéBonk：\(error.localizedDescription)\n请检查网络后重试。")
    }
}
