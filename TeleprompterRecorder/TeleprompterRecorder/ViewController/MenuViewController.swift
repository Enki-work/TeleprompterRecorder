//
//  MenuViewController.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2022/02/03.
//

import UIKit
import RxSwift
import RxCocoa
import SideMenu

class MenuViewController: UITableViewController {
    
    let disposeBag = DisposeBag()
    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionLabel.text = appVersion
        
        tableView.rx.itemSelected.subscribe(onNext: { [weak self] indexPath in
            guard let self = self else {
                return
            }
            self.tableView.deselectRow(at: indexPath, animated: true)
            switch indexPath.section {
            case 0:
                switch indexPath.row {
                case 0:
                    let vc = (self.presentingViewController as? UINavigationController)?.topViewController
                    vc?.performSegue(withIdentifier: "showContactMe", sender: nil)
                    SideMenuManager.default.rightMenuNavigationController?.dismiss(animated: false, completion: nil)
                default:
                    break
                }
            case 1:
                switch indexPath.row {
                case 0:
                    //何もしない
                    return
                default:
                    break
                }
            default:
                break
            }
        }).disposed(by: disposeBag)
    }

}
