//
//  Extension.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/20.
//

import UIKit
import AVFoundation
import RxCocoa

extension UIViewController {
    static var rootViewController: UIViewController? = {
        UIApplication.shared.windows.first?.rootViewController
    }()
}

extension UIAlertController {
    
    static func showCancelAlert(title: String, message: String? = nil,
                                cancelBtnTitle: String = "OK",
                                handler: ((UIAlertAction) -> Void)? = nil) {
        let alertController = UIAlertController(title: title,
                                                message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: cancelBtnTitle, style: .cancel, handler: handler)
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
extension UIDeviceOrientation {
    var AVCaptureVideoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .landscapeRight:
            return .landscapeLeft
        case .landscapeLeft:
            return .landscapeRight
        default:
            return .portrait
        }
    }
}

extension UIInterfaceOrientation {
    var AVCaptureVideoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .landscapeRight:
            return .landscapeRight
        case .landscapeLeft:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
}

extension UIWindow {
    static var orientation: UIInterfaceOrientation {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows
                .first?
                .windowScene?
                .interfaceOrientation ?? .portrait
        } else {
            return UIApplication.shared.statusBarOrientation
        }
    }
}

extension UserDefaults {
    static let PrompterViewShowKey = "PrompterViewShowKey"
    static let PrompterTextKey = "PrompterTextKey"
    static let isHDRSwitchKey = "isHDRSwitchKey"
    static let isPrompterAdsShowKey = "isPrompterAdsShowKey"
    
#if DEBUG
    private static let isPrompterAdsInterval: CGFloat = 60
#else
    private static let isPrompterAdsInterval: CGFloat = 60 * 60 * 24
#endif
    
    static func setDefaultValues() {
        UserDefaults.standard.register(defaults: [PrompterViewShowKey : false])
        UserDefaults.standard.register(defaults: [isHDRSwitchKey : false])
    }
    
    var isPrompterViewShow: Bool {
        UserDefaults.standard.bool(forKey:  UserDefaults.PrompterViewShowKey)
    }
    
    func setPrompterViewShow(value: Bool) {
        UserDefaults.standard.set(value, forKey: UserDefaults.PrompterViewShowKey)
    }
    
    var isHDRSwitch: Bool {
        UserDefaults.standard.bool(forKey:  UserDefaults.isHDRSwitchKey)
    }
    
    func setHDRSwitch(value: Bool) {
        UserDefaults.standard.set(value, forKey: UserDefaults.isHDRSwitchKey)
    }
    
    var isPrompterAdsShow: Bool {
        guard let showedDate = UserDefaults.standard.object(forKey: UserDefaults.isPrompterAdsShowKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(showedDate) > UserDefaults.isPrompterAdsInterval
    }
    
    func setPrompterAdsDate(value: Date) {
        UserDefaults.standard.set(value, forKey: UserDefaults.isPrompterAdsShowKey)
    }
    
    var prompterText: NSAttributedString? {
        guard let strData = UserDefaults.standard.object(forKey:  UserDefaults.PrompterTextKey) as? Data else {
            return nil
        }
        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(strData) as? NSAttributedString
    }
    
    func setPrompterText(text: NSAttributedString) {
        if let strData = try? NSKeyedArchiver.archivedData(withRootObject: text, requiringSecureCoding: true) {
            UserDefaults.standard.set(strData, forKey: UserDefaults.PrompterTextKey)
        }
    }
}

extension String {
    func decodeFromBase64() -> String {
        
        let data = Data(base64Encoded: self, options: [])
        
        let decodedStr = String(data: data ?? Data(), encoding: .utf8)
        
        return decodedStr ?? ""
        
    }
}
