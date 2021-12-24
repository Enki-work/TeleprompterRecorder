//
//  RewardedVideoView.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/12/24.
//

import UIKit
import GoogleMobileAds

class RewardedVideoview: UIView {
    
    enum GameState: NSInteger {
        case notStarted
        case playing
        case paused
        case ended
    }
    
    /// Constant for coin rewards.
    let gameOverReward = 1
    
    /// Starting time for game counter.
    let gameLength = 10
    
    /// Number of coins the user has earned.
    var coinCount = 0
    
    /// The rewarded video ad.
    var rewardedAd: GADRewardedAd?
    
    /// The countdown timer.
    var timer: Timer?
    
    /// The game counter.
    var counter = 10
    
    /// The state of the game.
    var gameState = GameState.notStarted
    
    /// The date that the timer was paused.
    var pauseDate: Date?
    
    /// The last fire date before a pause.
    var previousFireDate: Date?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Pause game when application is backgrounded.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.applicationDidEnterBackground(_:)),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Resume game when application is returned to foreground.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        startNewGame()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    fileprivate func startNewGame() {
        gameState = .playing
        counter = gameLength
        
        GADRewardedAd.load(
            withAdUnitID: "ca-app-pub-3940256099942544/1712485313", request: GADRequest()
        ) { (ad, error) in
            if let error = error {
                print("Rewarded ad failed to load with error: \(error.localizedDescription)")
                return
            }
            print("Loading Succeeded")
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.playAgain()
        }
        
        timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(self.timerFireMethod(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    @objc func applicationDidEnterBackground(_ notification: Notification) {
        // Pause the game if it is currently playing.
        if gameState != .playing {
            return
        }
        gameState = .paused
        
        // Record the relevant pause times.
        pauseDate = Date()
        previousFireDate = timer?.fireDate
        
        // Prevent the timer from firing while app is in background.
        timer?.fireDate = Date.distantFuture
    }
    
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        // Resume the game if it is currently paused.
        if gameState != .paused {
            return
        }
        gameState = .playing
        
        // Calculate amount of time the app was paused.
        let pauseTime = (pauseDate?.timeIntervalSinceNow)! * -1
        
        // Set the timer to start firing again.
        timer?.fireDate = (previousFireDate?.addingTimeInterval(pauseTime))!
    }
    
    @objc func timerFireMethod(_ timer: Timer) {
        counter -= 1
        if counter > 0 {
            //            gameText.text = String(counter)
        } else {
            endGame()
        }
    }
    
    fileprivate func earnCoins(_ coins: NSInteger) {
        coinCount += coins
        //        coinCountLabel.text = "Coins: \(self.coinCount)"
    }
    
    fileprivate func endGame() {
        gameState = .ended
        //        gameText.text = "Game over!"
        //        playAgainButton.isHidden = false
        timer?.invalidate()
        timer = nil
        earnCoins(gameOverReward)
    }
    
    // MARK: Button actions
    func playAgain() {
        if let ad = rewardedAd {
            ad.present(fromRootViewController: UIViewController.rootViewController!) {
                let reward = ad.adReward
                print("Reward received with currency \(reward.amount), amount \(reward.amount.doubleValue)")
                self.earnCoins(NSInteger(truncating: reward.amount))
                // TODO: Reward the user.
            }
        } else {
            UIAlertController.showCancelAlert(title: "Rewarded ad isn't available yet.",
                                              message: "The rewarded ad cannot be shown at this time",
                                              cancelBtnTitle: "OK",
                                              handler: { [weak self] action in
                self?.startNewGame()
            })
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}

extension RewardedVideoview: GADFullScreenContentDelegate {
    // MARK: GADFullScreenContentDelegate
    func adDidPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Rewarded ad presented.")
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Rewarded ad dismissed.")
    }
    
    func ad(
        _ ad: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("Rewarded ad failed to present with error: \(error.localizedDescription).")
        let alert = UIAlertController(
            title: "Rewarded ad failed to present",
            message: "The reward ad could not be presented.",
            preferredStyle: .alert)
        let alertAction = UIAlertAction(
            title: "Drat",
            style: .cancel,
            handler: { [weak self] action in
                self?.startNewGame()
            })
        alert.addAction(alertAction)
        UIViewController.rootViewController?.present(alert, animated: true, completion: nil)
    }
}
