//
//  RxExtension.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/20.
//

import RxSwift
import RxCocoa
import AVFoundation
import Photos

extension Reactive where Base: PHPhotoLibrary {
    static func requestAuthorization() -> Single<PHAuthorizationStatus> {
        return .create { observer in
            let status = Base.authorizationStatus()
            switch status {
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { status in
                    DispatchQueue.main.async {
                        observer(.success(status))
                    }
                }
            default:
                observer(.success(status))
            }
            return Disposables.create()
        }
    }
}

extension Reactive where Base: AVCaptureDevice {
    static func requestAuthorization(for mediaType: AVMediaType) -> Single<AVAuthorizationStatus> {
        return .create { observer in
            let status = Base.authorizationStatus(for: mediaType)
            switch status {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: mediaType) { authorized in
                    DispatchQueue.main.async {
                        observer(.success(authorized ? .authorized : .denied))
                    }
                }
            default:
                observer(.success(status))
            }
            return Disposables.create()
        }
    }
}
