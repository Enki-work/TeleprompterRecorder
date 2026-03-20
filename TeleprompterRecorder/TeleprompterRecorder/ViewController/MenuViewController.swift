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
        applyDarkStyle()
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

// MARK: - Dark appearance
private extension MenuViewController {
    func applyDarkStyle() {
        tableView.backgroundColor = UIColor(white: 0.07, alpha: 1)
        tableView.separatorColor  = UIColor.white.withAlphaComponent(0.09)
        view.backgroundColor      = UIColor(white: 0.07, alpha: 1)
        versionLabel?.textColor   = UIColor.white.withAlphaComponent(0.35)
    }
}

extension MenuViewController {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = .white
        cell.imageView?.tintColor = .systemCyan
        let sel = UIView()
        sel.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.12)
        cell.selectedBackgroundView = sel
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor  = UIColor.white.withAlphaComponent(0.45)
            header.textLabel?.font       = .systemFont(ofSize: 11, weight: .medium)
            header.contentView.backgroundColor = UIColor(white: 0.07, alpha: 1)
        }
    }
}
