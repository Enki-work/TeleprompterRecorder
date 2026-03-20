//
//  SceneDelegate.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/19.
//

import UIKit
import AppTrackingTransparency
import RxSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    private let disposeBag = DisposeBag()


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        
        NotificationCenter.default.rx.notification(UIApplication.didBecomeActiveNotification).take(until: self.rx.deallocated).subscribe { [weak self] notification in

            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {return}

            if let currentVC = self?.window?.rootViewController {
                ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
                    // 広告ロードをメインスレッド処理の安定後まで遅延させる
                    // （カメラ初期化・AdMob SDK起動が完了する前に広告を表示しようとすると
                    //   WebKit / Networking プロセスの生成が起動直後に集中し UI がフリーズする）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        appDelegate.showAdIfAvailable(viewController: currentVC)
                    }
                })
            }
        }.disposed(by: disposeBag)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func sceneWillResignActive(_ scene: UIScene) {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

