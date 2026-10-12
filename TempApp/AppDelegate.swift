import UIKit
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey:Any]?) -> Bool {
        let win = UIWindow(frame:UIScreen.main.bounds)
        win.backgroundColor = UIColor(red:3/255,green:20/255,blue:38/255,alpha:1)
        let nav = UINavigationController(rootViewController:ViewController())
        nav.navigationBar.barTintColor = win.backgroundColor
        nav.navigationBar.tintColor = .orange
        nav.navigationBar.titleTextAttributes = [.foregroundColor:UIColor.white]
        win.rootViewController = nav
        win.makeKeyAndVisible()
        window = win
        return true
    }
}
