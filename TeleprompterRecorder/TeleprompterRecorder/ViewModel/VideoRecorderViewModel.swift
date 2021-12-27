//
//  VideoRecorderViewModel.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/20.
//

import RxSwift
import RxCocoa
import UIKit
import AVFoundation
import Photos
import AudioToolbox

final class VideoRecorderViewModel: ViewModelType {
    
    struct Input {
        let ready: Driver<CameraPreview>
        let isVideoWillStart: Driver<Bool>
        let formats: Driver<Void>
        let changeCamera: Driver<Void>
        let prompterTextEditBtnClick: Driver<UIButton?>
    }
    
    struct Output {
        let requestAuthorizationFailed: Driver<Bool>
        let formats: Driver<(activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])?>
        let selectedFormat: Binder<AVCaptureDevice.Format>
        let didChangeCamera: Driver<Bool>
    }
    
    struct Dependencies {
        let captureManager: CaptureManager
    }
    
    private let dependencies: Dependencies
    private let disposeBag = DisposeBag()
    private var backgroundTaskID = UIBackgroundTaskIdentifier(rawValue: 0)
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    func transform(input: Input) -> Output {
        
        let requestAuthorization = input.ready.flatMap { _ in
            AVCaptureDevice.rx.requestAuthorization(for: .video).map({$0 == .authorized}).flatMap({ element -> Single<Bool> in
                if (element) {
                    return AVCaptureDevice.rx.requestAuthorization(for: .audio).map({$0 == .authorized})
                } else {
                    return Single.just(false)
                }
            }).flatMap({ element -> Single<Bool> in
                if (element) {
                    return PHPhotoLibrary.rx.requestAuthorization().map({$0 == .authorized})
                } else {
                    return Single.just(false)
                }
            }).asDriver(onErrorJustReturn: false)
        }
        
        let requestAuthorizationFailed: Driver<Bool> = Driver.combineLatest(input.ready, requestAuthorization).flatMap {
            if ($0.1) {
                let cameraPreview = $0.0
                cameraPreview.cameraPreviewLayer.session = self.dependencies.captureManager.captureSession
                self.dependencies.captureManager.initSetting()
            }
            return Driver<Bool>.just($0.1)
        }
        var isStopping = false
        input.isVideoWillStart.drive(onNext: { isVideoWillStart in
            guard !isStopping else {return}
            if (isVideoWillStart) {
                self.dependencies.captureManager.startRecording()
                self.sound(id: 1113)
            } else {
                isStopping = true
                self.dependencies.captureManager.stopRecording {
                    isStopping = false
                }
                self.sound(id: 1114)
            }
        }).disposed(by: disposeBag)
        
        input.prompterTextEditBtnClick.drive(onNext: { [weak self] btn in
            guard let self = self, let btn = btn else {return}
            btn.isUserInteractionEnabled = false
            let rewardedVideoManager = RewardedVideoManager()
            rewardedVideoManager.showRewardedVideoAd {[weak self] result  in
                guard let self = self, result else {return}
                btn.isUserInteractionEnabled = true
            }
            
            //            self.textViewEditButton.isSelected = !self.textViewEditButton.isSelected
            //            self.textView.isEditable = self.textViewEditButton.isSelected
            //            self.textView.isSelectable = self.textViewEditButton.isSelected
            //            if self.textViewEditButton.isSelected {
            //                self.textView.becomeFirstResponder()
            //            } else {
            //                self.textView.resignFirstResponder()
            //            }
            
            
        }).disposed(by: disposeBag)
        
        
        let formats: Driver<(activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])?> = input.formats.flatMap { _ in
            return self.dependencies.captureManager.currentCameraFormat
        }
        
        let didChangeCamera: Driver<Bool> = input.changeCamera.flatMap({[weak self] in
            guard let self = self else {return .just(false)}
            return self.dependencies.captureManager.changeCamera()
        })
        
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).subscribe { [weak self] notification in
            guard let self = self else {return}
            if self.dependencies.captureManager.isCapturing {
                self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {[weak self] in
                    guard let self = self else {return}
                    UIApplication.shared.endBackgroundTask((self.backgroundTaskID))
                })
                self.dependencies.captureManager.stopRecording {[weak self] in
                    guard let self = self else {return}
                    UIApplication.shared.endBackgroundTask((self.backgroundTaskID))
                }
            }
        }.disposed(by: disposeBag)
        
        return Output(requestAuthorizationFailed: requestAuthorizationFailed,
                      formats: formats,
                      selectedFormat: dependencies.captureManager.selectedFormat,
                      didChangeCamera: didChangeCamera)
    }
    
    private func sound(id: SystemSoundID) {
        var id = id
        if let soundUrl = CFBundleCopyResourceURL(CFBundleGetMainBundle(), nil, nil, nil) {
            AudioServicesCreateSystemSoundID(soundUrl, &id)
            AudioServicesPlaySystemSound(id)
        }
    }
}
