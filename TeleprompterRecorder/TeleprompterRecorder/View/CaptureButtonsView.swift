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
    
    let disposeBag = DisposeBag()
    
    override func awakeFromNib() {
        recordBtn.rx.tap.map({[weak self] in self?.recordBtn.isSelected ?? true}).bind(to: formatChangeBtn.rx.isEnabled).disposed(by: disposeBag)
    }
}
