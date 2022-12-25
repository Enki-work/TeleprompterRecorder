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
    @IBOutlet weak var textViewEditButton: UIButton!
    @IBOutlet weak var textView: UITextView! {
        didSet {
            if let attributedText = UserDefaults.standard.prompterText {
                textView.attributedText = attributedText
            }
        }
    }
    @IBOutlet weak var textViewBg: UIView!
    @IBOutlet weak var openPhotoBtn: UIButton!
    @IBOutlet weak var openMenuBtn: UIButton!
    
    let disposeBag = DisposeBag()
    
    override func awakeFromNib() {
        formatChangeBtn.imageView?.contentMode = .scaleAspectFit
        changeCameraBtn.imageView?.contentMode = .scaleAspectFit
        prompterBtn.imageView?.contentMode = .scaleAspectFit
        recordBtn.rx.tap.map({[weak self] in self?.recordBtn.isSelected ?? true}).bind(to: formatChangeBtn.rx.isEnabled).disposed(by: disposeBag)
        recordBtn.rx.tap.map({[weak self] in self?.recordBtn.isSelected ?? true}).bind(to: changeCameraBtn.rx.isEnabled).disposed(by: disposeBag)
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.endEditing(true)
    }
}
