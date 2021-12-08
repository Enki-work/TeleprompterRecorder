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
    @IBOutlet weak var textView: UITextView! {
        didSet {
            if let attributedText = UserDefaults.standard.prompterText {
                textView.attributedText = attributedText
            }
        }
    }
    @IBOutlet weak var textViewBg: UIView!
    @IBOutlet weak var textViewEditButton: UIButton!
    
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
        
        let obserable = NotificationCenter.default.rx.notification(Notification.Name.init(rawValue: notificationKey)).take(until: self.rx.deallocated).distinctUntilChanged({ a, b in
            if #available(iOS 15.0, *) {
                guard let aSequenceNumber = a.userInfo?["SequenceNumber"] as? Int,
                      let bSequenceNumber = b.userInfo?["SequenceNumber"] as? Int,
                      let aVolume = a.userInfo?["Volume"] as? Float,
                      let bVolume = b.userInfo?["Volume"] as? Float else {
                          return false
                      }
                if (aVolume == 1 && bVolume == 1) || (aVolume == 0 && bVolume == 0) {
                    return aSequenceNumber == bSequenceNumber
                } else {
                    return aSequenceNumber == bSequenceNumber || aVolume == bVolume
                }
            } else {
                guard let aVolume = a.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float,
                      let bVolume = b.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float else {
                          return false
                      }
                if (aVolume == 1 && bVolume == 1) || (aVolume == 0 && bVolume == 0) {
                    return false
                } else {
                    return aVolume == bVolume
                }
            }
        }).map { _ in}
        let manualTap = PublishSubject<Void>()
        obserable.observe(on: MainScheduler.asyncInstance).subscribe(on: MainScheduler.asyncInstance)
            .flatMapFirst {_ in
                obserable
                    .take(until: obserable.startWith(()).debounce(.milliseconds(500), scheduler: MainScheduler.instance))
                    .startWith(())
                    .reduce(0) { acc, _ in acc + 1 }
            }.delaySubscription(.milliseconds(1000), scheduler: MainScheduler.instance).subscribe(onNext: { [weak self] times in
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
                } else {
                    manualTap.onNext(())
                }
                
            }).disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).subscribe { [weak self] notification in
            guard let self = self else {return}
            self.recordBtn.isSelected = false
            self.formatChangeBtn.isEnabled = true
            self.changeCameraBtn.isEnabled = true
        }.disposed(by: disposeBag)
        let repos = Driver.merge(manualTap.asDriver(onErrorJustReturn: ()), prompterBtn.rx.tap.asDriver())
        let willPrompterBtnSelect = repos.map({ [weak self] () -> Bool in
                guard let self = self else {return false}
            UserDefaults.standard.setPrompterViewShow(value: !UserDefaults.standard.isPrompterViewShow)
            return self.prompterBtn.isSelected
        }).startWith(UserDefaults.standard.isPrompterViewShow).map({!$0})
        willPrompterBtnSelect.asObservable().bind(to: prompterBtn.rx.isSelected).disposed(by: disposeBag)
        willPrompterBtnSelect.asObservable().bind(to: textViewBg.rx.isHidden).disposed(by: disposeBag)
        textViewEditButton.rx.tap.subscribe(onNext: { [weak self] in
            guard let self = self else {return}
            self.textViewEditButton.isSelected = !self.textViewEditButton.isSelected
            self.textView.isEditable = self.textViewEditButton.isSelected
            self.textView.isSelectable = self.textViewEditButton.isSelected
            if self.textViewEditButton.isSelected {
                self.textView.becomeFirstResponder()
            } else {
                self.textView.resignFirstResponder()
            }
        }).disposed(by: disposeBag)
        textView.rx.didEndEditing.subscribe(onNext: { [weak self] in
            guard let self = self else {return}
            UserDefaults.standard.setPrompterText(text: self.textView.attributedText)
        }).disposed(by: disposeBag)
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.endEditing(true)
    }
}
