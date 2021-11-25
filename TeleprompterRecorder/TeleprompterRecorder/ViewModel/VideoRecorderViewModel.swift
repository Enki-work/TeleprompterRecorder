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

final class VideoRecorderViewModel: ViewModelType {
    
    struct Input {
        let ready: Driver<CameraPreview>
        let isVideoWillStart: Driver<Bool>
        let formats: Driver<Void>
        let changeCamera: Driver<Void>
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
//                cameraPreview.cameraPreviewLayer.connection?.videoOrientation = UIDevice.current.orientation.AVCaptureVideoOrientation
            }
            return Driver<Bool>.just($0.1)
        }
        var isStopping = false
        input.isVideoWillStart.drive(onNext: { isVideoWillStart in
            guard !isStopping else {return}
            if (isVideoWillStart) {
                self.dependencies.captureManager.startRecording()
            } else {
                isStopping = true
                self.dependencies.captureManager.stopRecording {
                    isStopping = false
                }
            }
        }).disposed(by: disposeBag)
        
        let formats: Driver<(activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])?> = input.formats.flatMap { _ in
            return self.dependencies.captureManager.currentCameraFormat
        }
        
        let didChangeCamera: Driver<Bool> = input.changeCamera.flatMap({[weak self] in
            guard let self = self else {return .just(false)}
            let result = (try? self.dependencies.captureManager.changeCamera()) ?? false
            return .just(result)
        })
        
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).subscribe { [weak self] notification in
            guard let self = self else {return}
            if self.dependencies.captureManager.isCapturing {
                self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {[weak self] in
                    guard let self = self else {return}
                    UIApplication.shared.endBackgroundTask((self.backgroundTaskID))
                    self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
                })
                self.dependencies.captureManager.stopRecording {[weak self] in
                    guard let self = self else {return}
                    UIApplication.shared.endBackgroundTask((self.backgroundTaskID))
                    self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
                }
            }
        }.disposed(by: disposeBag)
        
        return Output(requestAuthorizationFailed: requestAuthorizationFailed,
                      formats: formats,
                      selectedFormat: dependencies.captureManager.selectedFormat,
                      didChangeCamera: didChangeCamera)
    }
}
