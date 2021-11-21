//
//  Extension.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/20.
//

import UIKit

extension UIViewController {
    static var rootViewController: UIViewController? = {
        UIApplication.shared.windows.first?.rootViewController
    }()
}

extension UIAlertController {
    
    static func showCancelAlert(title: String, message: String? = nil, cancelBtnTitle: String = "OK") {
        let alertController = UIAlertController(title: title,
                                                message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: cancelBtnTitle, style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIViewController.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }
    
    static func showTwoBtnAlert(title: String,
                                message: String? = nil,
                                cancelBtnTitle: String = "OK",
                                secondBtnTitle: String,
                                secondBtnHandler: ((UIAlertAction) -> Void)? = nil) {
        let alertController = UIAlertController(title: title,
                                                message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: cancelBtnTitle, style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        let secondBtnAction = UIAlertAction(title: secondBtnTitle, style: .default, handler: secondBtnHandler)
        alertController.addAction(secondBtnAction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIViewController.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }
}
