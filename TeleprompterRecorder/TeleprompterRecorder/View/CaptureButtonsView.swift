//
//  CaptureButtonsView.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/21.
//

import UIKit
import RxCocoa
import RxSwift

class CaptureButtonsView: UIView {
    @IBOutlet weak var recordBtn: UIButton!
    @IBOutlet weak var formatChangeBtn: UIButton!
    @IBOutlet weak var changeCameraBtn: UIButton!
    @IBOutlet weak var prompterBtn: UIButton!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var textViewBg: UIView!
    
    let disposeBag = DisposeBag()
    
    override func awakeFromNib() {
        formatChangeBtn.imageView?.contentMode = .scaleAspectFit
        changeCameraBtn.imageView?.contentMode = .scaleAspectFit
        prompterBtn.imageView?.contentMode = .scaleAspectFit
        recordBtn.rx.tap.map({[weak self] in self?.recordBtn.isSelected ?? true}).bind(to: formatChangeBtn.rx.isEnabled).disposed(by: disposeBag)
        recordBtn.rx.tap.map({[weak self] in self?.recordBtn.isSelected ?? true}).bind(to: changeCameraBtn.rx.isEnabled).disposed(by: disposeBag)
        
        var notificationKey = ""
        if #available(iOS 15.0, *) {
            notificationKey = "SystemVolumeDidChange"
        } else {
            notificationKey = "AVSystemController_SystemVolumeDidChangeNotification"
        }
        
        let obserable = NotificationCenter.default.rx.notification(Notification.Name.init(rawValue: notificationKey)).take(until: self.rx.deallocated).map { _ in}
        
        obserable
            .flatMapFirst {_ in
                obserable
                    .take(until: obserable.startWith(()).debounce(.milliseconds(500), scheduler: MainScheduler.instance))
                    .startWith(())
                    .reduce(0) { acc, _ in acc + 1 }
            }
            .map { min($0, 2) }.delaySubscription(.milliseconds(1000), scheduler: MainScheduler.instance).subscribe(onNext: { [weak self] times in
                let offset: CGFloat = 30
                if (times == 1) {
                    guard let self = self,
                    !self.textView.isHidden,
                    self.textView.contentSize.height >= self.textView.contentOffset.y else {return}

                    let shouldY = min(self.textView.contentOffset.y + self.textView.bounds.height - offset , self.textView.contentSize.height - self.textView.bounds.height)
                    self.textView.setContentOffset(.init(x: self.textView.contentOffset.x, y: shouldY), animated: true)
                } else if times == 2 {
                    guard let self = self,
                    !self.textView.isHidden,
                          self.textView.contentOffset.y >= 0 else {return}

                    let shouldY = max(self.textView.contentOffset.y - self.textView.bounds.height + offset , 0)
                    self.textView.setContentOffset(.init(x: self.textView.contentOffset.x, y: shouldY), animated: true)
                }
                
            }).disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).subscribe { [weak self] notification in
            guard let self = self else {return}
            self.recordBtn.isSelected = false
            self.formatChangeBtn.isEnabled = true
            self.changeCameraBtn.isEnabled = true
        }.disposed(by: disposeBag)
        
        let willPrompterBtnSelect = prompterBtn.rx.tap.asDriver().map({ [weak self] () -> Bool in
                guard let self = self else {return false}
            let flag = !self.prompterBtn.isSelected
            UserDefaults.standard.setPrompterViewShow(value: flag)
            return flag
        }).startWith(UserDefaults.standard.isPrompterViewShow)
        willPrompterBtnSelect.asObservable().bind(to: prompterBtn.rx.isSelected).disposed(by: disposeBag)
        willPrompterBtnSelect.asObservable().bind(to: textViewBg.rx.isHidden).disposed(by: disposeBag)
        
    }
}
