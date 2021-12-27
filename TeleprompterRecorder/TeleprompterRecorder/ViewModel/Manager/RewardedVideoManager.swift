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
        GADRewardedAd.load(
            withAdUnitID: "ca-app-pub-3940256099942544/1712485313", request: GADRequest()
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
            UIAlertController.showCancelAlert(title: "Rewarded ad isn't available yet.",
                                              message: "The rewarded ad cannot be shown at this time",
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
                self?.showRewardedVideoAd(completion: self?.completion)
            })
        alert.addAction(alertAction)
        UIViewController.rootViewController?.present(alert, animated: true, completion: nil)
    }
}
