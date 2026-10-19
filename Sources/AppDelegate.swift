import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 游戏过程中不要锁屏
        UIApplication.shared.isIdleTimerDisabled = true

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor(red: 0.102, green: 0.086, blue: 0.188, alpha: 1.0)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }

    /// 进前台时重新激活播放用音频会话：网页音频就不会被静音拨杆掐掉
    func applicationDidBecomeActive(_ application: UIApplication) {
        AudioSession.activateForPlayback()
    }
}
