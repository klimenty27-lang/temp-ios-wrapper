import UIKit
import UserNotifications
@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.badge,.sound]) { granted,_ in
            if granted { DispatchQueue.main.async { application.registerForRemoteNotifications() } }
        }
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        let value=token.map { String(format:"%02x",$0) }.joined()
        if let nav=window?.rootViewController as? UINavigationController,
           let vc=nav.viewControllers.first as? ViewController { vc.receivedPushToken(value) }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("TEMP push registration unavailable: %@",error.localizedDescription)
    }
    func userNotificationCenter(_ center:UNUserNotificationCenter, willPresent notification:UNNotification,
                                withCompletionHandler completionHandler:@escaping(UNNotificationPresentationOptions)->Void) {
        completionHandler([.banner,.sound,.badge])
    }
}
