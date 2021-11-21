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
        let ready: Driver<AVCaptureVideoPreviewLayer>
    }
    
    struct Output {
        let requestAuthorizationFailed: Driver<Bool>
        let notification: Driver<Notification>
    }
    
    struct Dependencies {
        var captureManager: CaptureManager
    }
    
    private var dependencies: Dependencies
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    func transform(input: Input) -> Output {
        
        let loading = ActivityIndicator()
        
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
                $0.0.session = self.dependencies.captureManager.captureSession
                self.dependencies.captureManager.start()
                self.dependencies.captureManager.captureSession.startRunning()
            }
            return Driver<Bool>.just($0.1)
        }
        
        let notification = Observable<Notification>.merge(NotificationCenter.default.rx.notification(NSNotification.Name.AVCaptureSessionRuntimeError), NotificationCenter.default.rx.notification(NSNotification.Name.AVCaptureDeviceWasDisconnected)).asDriver(onErrorJustReturn: .init(name: NSNotification.Name.AVCaptureSessionRuntimeError, object: nil, userInfo: nil))
        
        return Output(requestAuthorizationFailed: requestAuthorizationFailed,
                      notification: notification)
    }
}
