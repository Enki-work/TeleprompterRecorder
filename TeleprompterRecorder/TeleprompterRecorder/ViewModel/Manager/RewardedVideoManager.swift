//
//  RewardedVideoManager.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/12/24.
//

import UIKit
import GoogleMobileAds

class RewardedVideoManager: NSObject {
    
    /// The rewarded video ad.
    private var rewardedAd: GADRewardedAd?
    private var completion: ((Bool) -> Void)?
    
    func showRewardedVideoAd(completion: ((Bool) -> Void)? = nil) {
        let APP_REWARDED_AD_ID = Bundle.main.infoDictionary?["APP_REWARDED_AD_ID"] as? String ?? "ca-app-pub-3940256099942544/1712485313"
        GADRewardedAd.load(
            withAdUnitID: APP_REWARDED_AD_ID, request: GADRequest()
        ) { (ad, error) in
            if let error = error {
                print("Rewarded ad failed to load with error: \(error.localizedDescription)")
                completion?(false)
                return
            }
            print("Loading Succeeded")
            self.completion = completion
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.play()
        }
    }
    
    fileprivate func play() {
        if let ad = rewardedAd {
            ad.present(fromRootViewController: UIViewController.rootViewController!) {
                let reward = ad.adReward
                print("Reward received with currency \(reward.amount), amount \(reward.amount.doubleValue)")
                self.completion?(true)
                self.completion = nil
            }
        } else {
            UIAlertController.showCancelAlert(title: "リワード広告表示できません",
                                              cancelBtnTitle: "OK",
                                              handler: { [weak self] action in
                self?.showRewardedVideoAd(completion: self?.completion)
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

extension RewardedVideoManager: GADFullScreenContentDelegate {
    // MARK: GADFullScreenContentDelegate
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Rewarded ad dismissed.")
    }
    
    func ad(
        _ ad: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("Rewarded ad failed to present with error: \(error.localizedDescription).")
        
        UIAlertController.showCancelAlert(title: "リワード広告表示が失敗しました",
                                          cancelBtnTitle: "リトライ",
                                          handler: { [weak self] action in
            self?.showRewardedVideoAd(completion: self?.completion)
        })
    }
}
