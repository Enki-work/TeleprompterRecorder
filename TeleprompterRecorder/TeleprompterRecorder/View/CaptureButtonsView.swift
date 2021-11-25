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
    @IBOutlet weak var textView: UITextView!
    
    let disposeBag = DisposeBag()
    
    override func awakeFromNib() {
        recordBtn.rx.tap.map({[weak self] in self?.recordBtn.isSelected ?? true}).bind(to: formatChangeBtn.rx.isEnabled).disposed(by: disposeBag)
        let obserable = NotificationCenter.default.rx.notification(Notification.Name.init(rawValue: "AVSystemController_SystemVolumeDidChangeNotification")).take(until: self.rx.deallocated).map { _ in}
        
        obserable
            .flatMapFirst {_ in
                obserable
                    .take(until: obserable.startWith(()).debounce(.milliseconds(300), scheduler: MainScheduler.instance))
                    .startWith(())
                    .reduce(0) { acc, _ in acc + 1 }
            }
            .map { min($0, 2) }.delaySubscription(.milliseconds(1000), scheduler: MainScheduler.instance).subscribe { [weak self] times in
                print("!!!!!!\(times)")
                guard let self = self,
                !self.textView.isHidden,
                self.textView.contentSize.height >= self.textView.contentOffset.y else {return}

                let shouldY = min(self.textView.contentOffset.y + self.textView.bounds.height , self.textView.contentSize.height - self.textView.bounds.height)
                self.textView.contentOffset = .init(x: self.textView.contentOffset.x, y: shouldY)
            }.disposed(by: disposeBag)
    }
}
