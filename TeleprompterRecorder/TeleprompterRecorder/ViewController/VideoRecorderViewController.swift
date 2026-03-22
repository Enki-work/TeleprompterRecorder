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
    lazy var viewModel = VideoRecorderViewModel(dependencies:
                                                .init(captureManager: CaptureManager(captureSession: AVCaptureSession()),
                                                      videoRecorderVC: self))
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
        setupFocusTapGesture()
    }
    
    private func bindViewModel() {
        
        let input = VideoRecorderViewModel.Input(ready: rx.viewWillAppear.flatMap({Driver.just(self.cameraPreview)}).asDriver(onErrorJustReturn: self.cameraPreview),
                                                 isVideoWillStart: cameraPreview.captureButtonsView.recordBtn.rx.tap.asDriver().flatMap({
            let isVideoWillStart = !self.cameraPreview.captureButtonsView.recordBtn.isSelected
            self.cameraPreview.captureButtonsView.recordBtn.isSelected = isVideoWillStart
            return Driver.just(isVideoWillStart)
        }),
                                                 formats: cameraPreview.captureButtonsView.formatChangeBtn.rx.tap.asDriver(),
                                                 changeCamera: cameraPreview.captureButtonsView.changeCameraBtn.rx.tap.map({[weak self]_ in self?.cameraPreview.captureButtonsView.changeCameraBtn}).asDriver(onErrorJustReturn: nil),
                                                 prompterTextEditBtnClick: cameraPreview.captureButtonsView.textViewEditButton.rx.tap.map({self.cameraPreview.captureButtonsView}).asDriver(onErrorJustReturn: nil), openPhotoBtnClick: cameraPreview.captureButtonsView.openPhotoBtn.rx.tap.asDriver())
        
        let output = viewModel.transform(input: input)
        
        output.requestAuthorizationFailed.drive(onNext: { result in
            if !result {
                UIAlertController.showTwoBtnAlert(title: L("permission.message"), secondBtnTitle: L("permission.go_settings")) { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
        }).disposed(by: disposeBag)
        
        output.formats.drive(onNext: { [weak self] formats in
            self?.performSegue(withIdentifier: "showformatlist", sender: (formats, output.selectedFormat))
        }).disposed(by: disposeBag)
        
        output.didChangeCamera.drive(onNext: {[weak self]result in
            guard result else {return}
            self?.cameraPreview.cameraPreviewLayer.connection?.videoOrientation = UIWindow.orientation.AVCaptureVideoOrientation
        }).disposed(by: disposeBag)
        
        cameraPreview.captureButtonsView.openMenuBtn.rx.tap.asDriver().drive(onNext: { [weak self] in
            guard let self = self else { return }
            self.performSegue(withIdentifier: "showMenu", sender: nil)
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
        
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification).take(until: self.rx.deallocated).subscribe { [weak self] notification in
            let orientation = UIWindow.orientation.AVCaptureVideoOrientation
            self?.cameraPreview.cameraPreviewLayer.connection?.videoOrientation = orientation
            // videoDataOutput の orientation も常に同期させておく
            // （録画開始時に変更するとパイプライン停止が起きるためここで管理する）
            self?.viewModel.dependencies.captureManager.updateVideoOrientation(orientation)
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
            formatListVC.title = L("format.title")
            formatListVC.formats = sender.0
            formatListVC.selectedFormat.bind(to: sender.1).disposed(by: formatListVC.disposeBag)
        }
    }
    
    // MARK: - Touch to Focus

    private func setupFocusTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFocusTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        cameraPreview.addGestureRecognizer(tap)

        // 被摄体变化时恢复连续自动对焦
        NotificationCenter.default.rx
            .notification(AVCaptureDevice.subjectAreaDidChangeNotification)
            .take(until: rx.deallocated)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.viewModel.dependencies.captureManager.resetFocusAndExposure()
            }).disposed(by: disposeBag)
    }

    @objc private func handleFocusTap(_ gesture: UITapGestureRecognizer) {
        // 提词器编辑模式下不触发对焦（让键盘操作正常工作）
        guard !cameraPreview.captureButtonsView.textView.isEditable else { return }
        let point = gesture.location(in: cameraPreview)
        let devicePoint = cameraPreview.cameraPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        viewModel.dependencies.captureManager.focus(at: devicePoint)
        cameraPreview.showFocusIndicator(at: point)
    }

    override var prefersStatusBarHidden: Bool { true }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        cameraPreview.captureButtonsView.textView.contentOffset = .zero
    }
}

// MARK: - UIGestureRecognizerDelegate (Focus tap)
extension VideoRecorderViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        // 触摸落在 UIControl（按钮等）或其子视图上时，不触发对焦
        var view = touch.view
        while let v = view {
            if v is UIControl { return false }
            view = v.superview
        }
        return true
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
