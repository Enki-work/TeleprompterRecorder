//
//  VideoRecorderViewController.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/20.
//

import UIKit
import RxSwift
import RxCocoa
import AVFoundation

class VideoRecorderViewController: UIViewController {
    let viewModel = VideoRecorderViewModel(dependencies: .init(captureManager: CaptureManager(captureSession: AVCaptureSession())))
    // プレビュー表示用のレイヤ
    var cameraPreviewLayer : AVCaptureVideoPreviewLayer {
        (view as! CameraPreview).layer as! AVCaptureVideoPreviewLayer
    }
    
    let disposeBag = DisposeBag()
    
    
    override func loadView() {
        self.view = CameraPreview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        bindNotification()
    }
    
    private func bindViewModel() {
        let input = VideoRecorderViewModel.Input(ready: rx.viewWillAppear.flatMap({Driver.just(self.cameraPreviewLayer)}).asDriver(onErrorJustReturn: self.cameraPreviewLayer))

        let output = viewModel.transform(input: input)
        
        output.requestAuthorizationFailed.drive(onNext: { result in
            if !result {
                UIAlertController.showTwoBtnAlert(title: "アプリ正常に使用するのに必要の権限オンにしてください", secondBtnTitle: "設定画面へ") { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
        }).disposed(by: disposeBag)
    }
    
    private func bindNotification() {
        NotificationCenter.default.rx.notification(NSNotification.Name.AVCaptureSessionRuntimeError).take(until: self.rx.deallocated).subscribe { notification in
            debugPrint("AVCaptureSessionRuntimeError")
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(NSNotification.Name.AVCaptureDeviceWasDisconnected).take(until: self.rx.deallocated).subscribe { notification in
            debugPrint("AVCaptureDeviceWasDisconnected")
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(NSNotification.Name.AVCaptureSessionDidStartRunning).take(until: self.rx.deallocated).subscribe { notification in
            debugPrint("AVCaptureSessionDidStartRunning")
        }.disposed(by: disposeBag)
    }
}
