//
//  AppDelegate.swift
//  Example
//
//  Created by Qiscus on 07/11/18.
//  Copyright © 2018 Qiscus. All rights reserved.
//

import UIKit
import QiscusCore
import Foundation
import UserNotifications
import SwiftyJSON
import QiscusMeet

let APP_ID : String = "sdksample"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var presenter = UIChatListPresenter()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        QiscusCore.enableDebugMode(value: true)
        QiscusCore.setup(AppID: APP_ID)
        QiscusMeet.setup(appId: "qiscus-lMNhoA0fw7CDAY8d", url: "https://meet.qiscus.com")
        let meetConfig = MeetJwtConfig()
        //Change with users email
        meetConfig.email = "gustu@qiscus.net"
        QiscusMeetConfig.shared.setJwtConfig = meetConfig
        //
        QiscusMeetConfig.shared.setEnableRoomName = false
        QiscusMeetConfig.shared.setChat = false
        QiscusMeetConfig.shared.setOverflowMenu = true
        QiscusMeetConfig.shared.setVideoThumbnailsOn = false
        QiscusMeetConfig.shared.setEnableScreenSharing = true
        QiscusMeetConfig.shared.setEnableScreenSharing = false
        QiscusMeetConfig.shared.setChat = false
        UINavigationBar.appearance().barTintColor = UIColor.white
        UINavigationBar.appearance().tintColor = UIColor.white
        self.auth()
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()
        return true
    }
    
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        var tokenString: String = ""
        for i in 0..<deviceToken.count {
            tokenString += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
        }
        print("token = \(tokenString)")
        UserDefaults.standard.setDeviceToken(value: tokenString)
        if QiscusCore.hasSetupUser() {
            //change isDevelopment to false for production and true for development
            QiscusCore.shared.registerDeviceToken(token: tokenString, onSuccess: { (response) in
                print("success register device token =\(tokenString)")
            }) { (error) in
                print("failed register device token = \(error.message)")
            }
        }

    }
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        print("AppDelegate. didReceive: \(notification)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        print("AppDelegate. didReceiveRemoteNotification: \(userInfo)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("AppDelegate. didReceiveRemoteNotification2: \(userInfo)")
        
        //you can custom redirect to chatRoom
        
        let userInfoJson = JSON(arrayLiteral: userInfo)[0]
        if let payload = userInfo["payload"] as? [String: Any] {
            if let payloadData = payload["payload"] {
                let jsonPayload = JSON(arrayLiteral: payload)[0]
                
                let messageID = jsonPayload["id_str"].string ?? ""
                let roomID = jsonPayload["room_id_str"].string ?? ""
            
                if !messageID.isEmpty && !roomID.isEmpty{
                    QiscusCore.shared.markAsDelivered(roomId: roomID, commentId: messageID)
                }
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

extension AppDelegate {
    // Auth
    func auth() {
        let target : UIViewController
        if QiscusCore.hasSetupUser() {
            target = UIChatListViewController()
            _ = QiscusCore.connect(delegate: self)
            QiscusCore.delegate = self
            QiscusMeet.shared.QiscusMeetDelegate = self
        }else {
            target = LoginViewController()
        }
        let navbar = UINavigationController()
        navbar.viewControllers = [target]
        self.window = UIWindow.init(frame: UIScreen.main.bounds)
        self.window?.rootViewController = navbar
        self.window?.makeKeyAndVisible()
        
    }
    
    func registerDeviceToken(){
        if let deviceToken = UserDefaults.standard.getDeviceToken(){
            //change isDevelopment to false for production and true for development
            QiscusCore.shared.registerDeviceToken(token: deviceToken, onSuccess: { (success) in
                print("success register device token =\(deviceToken)")
            }) { (error) in
                print("failed register device token = \(error.message)")
            }
        }
    }
}

extension AppDelegate : QiscusConnectionDelegate {
    func onConnected(){
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "reSubscribeRoom"), object: nil)
    }
    func onReconnecting(){
        
    }
    func onDisconnected(withError err: QError?){
        
    }
    
    func connectionState(change state: QiscusConnectionState) {
        if (state == .disconnected){
            var roomsId = [String]()
            
            let rooms = QiscusCore.database.room.all()
            
            if rooms.count != 0{
                
                for room in rooms {
                    roomsId.append(room.id)
                }
                
                QiscusCore.shared.getChatRooms(roomIds: roomsId, showRemoved: false, showParticipant: true, onSuccess: { (rooms) in
                    //brodcast rooms to your update ui ex in ui listRoom
                }, onError: { (error) in
                    print("error = \(error.message)")
                })
                
            }
            
        }
        
    }
}

// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // Print full message.
        print(userInfo)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Print full message.
        print(userInfo)
        
        completionHandler()
    }
}
// [END ios_10_message_handling]
extension AppDelegate : QiscusCoreDelegate {
    func onRoomMessageReceived(_ room: RoomModel, message: CommentModel) {
        let profile = QiscusCore.getProfile()
        let type = message.type
        if(type == "call"){
            let status = message.extras!["status"] as! String
            if(message.isMyComment()){
                if(status == "answer"){
                    QiscusMeet.call(isVideo: true, isMicMuted: false, room: room.id , avatarUrl: profile!.avatarUrl.absoluteString , displayName: profile!.username,callKitName: "Qiscus Chat", onSuccess: { (vc) in
                        vc.modalPresentationStyle = .fullScreen
                        if let window = self.window, let rootViewController = window.rootViewController {
                            var currentController = rootViewController
                            while let presentedController = currentController.presentedViewController {
                                currentController = presentedController
                            }
                            currentController.present(vc, animated: true)

                        }
                    }) { (error) in
                        print("meet error =\(error)")
                    }
                }else if  (status == "calling"){
                    let vc = CallVC()
                    vc.isCaller = true
                    vc.isCalling = true
                    vc.room = room
                    vc.modalPresentationStyle = .fullScreen
                    if let window = self.window, let rootViewController = window.rootViewController {
                            var currentController = rootViewController
                            while let presentedController = currentController.presentedViewController {
                                currentController = presentedController
                            }
                        currentController.present(vc, animated: true)

                        }
                    
                }
                else if(status == "reject"){
                    UIApplication.shared.keyWindow!.rootViewController?.dismiss(animated: true, completion: nil)
                }
            } else{
                if(status == "answer"){
                    QiscusMeet.call(isVideo: true, isMicMuted: false, room: room.id , avatarUrl: profile!.avatarUrl.absoluteString , displayName: profile!.username,callKitName: "Qiscus Chat", onSuccess: { (vc) in
                        vc.modalPresentationStyle = .fullScreen
                        if let window = self.window, let rootViewController = window.rootViewController {
                            var currentController = rootViewController
                            while let presentedController = currentController.presentedViewController {
                                currentController = presentedController
                            }
                            currentController.present(vc, animated: true)
                     }
                    }) { (error) in
                        print("meet error =\(error)")
                    }
                }else if(status == "calling"){
                    let vc = CallVC()
                    vc.isCaller = false
                    vc.isCalling = true
                    vc.room = room
                    vc.modalPresentationStyle = .fullScreen
                        if let window = self.window, let rootViewController = window.rootViewController {
                            var currentController = rootViewController
                            while let presentedController = currentController.presentedViewController {
                                currentController = presentedController
                            }
                            currentController.present(vc, animated: true)

                        }
                }  else if(status == "reject"){
                    UIApplication.shared.keyWindow!.rootViewController?.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    func onRoomMessageUpdated(_ room: RoomModel, message: CommentModel) {
    
    }
    
    func onRoomMessageDeleted(room: RoomModel, message: CommentModel) {
        
    }
    
    func onRoomDidChangeComment(comment: CommentModel, changeStatus status: CommentStatus) {
        
    }
    
    func onRoomMessageDelivered(message: CommentModel) {
        
    }
    
    func onRoomMessageRead(message: CommentModel) {
        
    }
    
    func onRoom(update room: RoomModel) {
        
    }
    
    func onRoom(deleted room: RoomModel) {
        
    }
    
    func gotNew(room: RoomModel) {
        
    }
    
    func onChatRoomCleared(roomId: String) {
        
    }
    
    
}
extension AppDelegate : QiscusMeetDelegate {
    func conferenceJoined() {
        
    }
    
    func conferenceWillJoin() {
        
    }
    
    func conferenceTerminated() {
    }
    
    func participantJoined() {
        
    }
    
    func participantLeft() {
        QiscusMeet.endCall()
    }
    
    
}
