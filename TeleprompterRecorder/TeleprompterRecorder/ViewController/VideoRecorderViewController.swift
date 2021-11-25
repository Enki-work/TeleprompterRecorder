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
import MediaPlayer

class VideoRecorderViewController: UIViewController {
    let viewModel = VideoRecorderViewModel(dependencies: .init(captureManager: CaptureManager(captureSession: AVCaptureSession())))
    // プレビュー
    var cameraPreview : CameraPreview {
        view as! CameraPreview
    }
    
    private let disposeBag = DisposeBag()
    
    override func loadView() {
        self.view = CameraPreview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        bindNotification()
        hideVolumeView()
    }
    
    private func bindViewModel() {
        
        let input = VideoRecorderViewModel.Input(ready: rx.viewWillAppear.flatMap({Driver.just(self.cameraPreview)}).asDriver(onErrorJustReturn: self.cameraPreview),
                                                 isVideoWillStart: cameraPreview.captureButtonsView.recordBtn.rx.tap.asDriver().flatMap({
            let isVideoWillStart = !self.cameraPreview.captureButtonsView.recordBtn.isSelected
            self.cameraPreview.captureButtonsView.recordBtn.isSelected = isVideoWillStart
            return Driver.just(isVideoWillStart)
        }),
                                                 formats: cameraPreview.captureButtonsView.formatChangeBtn.rx.tap.asDriver(),
                                                 changeCamera: cameraPreview.captureButtonsView.changeCameraBtn.rx.tap.asDriver())
        
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
        
        output.formats.drive(onNext: { [weak self] formats in
            self?.performSegue(withIdentifier: "showformatlist", sender: (formats, output.selectedFormat))
        }).disposed(by: disposeBag)
        
        output.didChangeCamera.drive(onNext: {_ in }).disposed(by: disposeBag)
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
        
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification).take(until: self.rx.deallocated).subscribe { [weak self] notification in
            self?.cameraPreview.cameraPreviewLayer.connection?.videoOrientation = UIWindow.orientation.AVCaptureVideoOrientation
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(Notification.Name.init(rawValue: "AVSystemController_SystemVolumeDidChangeNotification")).skip(until: rx.viewDidAppear.asObservable()).take(until: self.rx.deallocated).subscribe { [weak self] notification in
            print("AVSystemController_SystemVolumeDidChangeNotification")
        }.disposed(by: disposeBag)
        
    }
    
    private func hideVolumeView() {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.alpha = 0.01
        self.view.addSubview(volumeView)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showformatlist",
            let formatListVC = segue.destination as? FormatListViewController,
        let sender = sender as? ((activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format]), Binder<AVCaptureDevice.Format>) {
            formatListVC.title = "FormatList"
            formatListVC.formats = sender.0
            formatListVC.selectedFormat.bind(to: sender.1).disposed(by: formatListVC.disposeBag)
        }
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        true
    }
}

extension UINavigationController {
    open override var shouldAutorotate: Bool {
        topViewController?.shouldAutorotate ?? true
    }
    
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        topViewController?.supportedInterfaceOrientations ?? .all
    }
}
