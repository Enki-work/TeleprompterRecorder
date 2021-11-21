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
    }
    
    struct Output {
        let requestAuthorizationFailed: Driver<Bool>
    }
    
    struct Dependencies {
        let captureManager: CaptureManager
    }
    
    private let dependencies: Dependencies
    private let disposeBag = DisposeBag()
    
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
                self.dependencies.captureManager.captureSession.startRunning()
            }
            return Driver<Bool>.just($0.1)
        }
        
        input.isVideoWillStart.drive(onNext: { isVideoWillStart in
            if (isVideoWillStart) {
                self.dependencies.captureManager.startRecording()
            }
        }).disposed(by: disposeBag)
        
        return Output(requestAuthorizationFailed: requestAuthorizationFailed)
    }
}
