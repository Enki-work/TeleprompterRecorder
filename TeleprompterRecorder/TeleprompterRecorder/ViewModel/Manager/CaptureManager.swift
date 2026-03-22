//
//  CaptureManager.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/21.
//

import AVFoundation
import Photos
import UIKit
import RxSwift
import RxCocoa

class CaptureManager: NSObject {
    
    let captureSession: AVCaptureSession
    private let recordingQueue = DispatchQueue.init(label: "CaptureManager")
    private var recordEncoder: CaptureEncoder?
    private var timeOffset = CMTime.zero
    private var lastVideo = CMTime.zero
    private var lastAudio = CMTime.zero
    private var startTime = CMTime.zero
    private var currentRecordTime: Float64 = 0
    
    private(set) var isCapturing = false
    
    // メインカメラの管理オブジェクトの作成
    private var mainCamera: AVCaptureDevice?
    // インカメの管理オブジェクトの作成
    private var innerCamera: AVCaptureDevice?
    // 現在使用しているカメラデバイスの管理オブジェクトの作成
    private var currentCamera: AVCaptureDevice?
    // 現在使用しているカメラデバイスの管理オブジェクトの作成
    private var currentAudio: AVCaptureDevice?
    
    // 出力データを受け付けるオブジェクト
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    
    lazy var selectedFormat: Binder<AVCaptureDevice.Format> = .init(self) { manager, format in
        guard let currentCamera = manager.currentCamera else {return}
        try? currentCamera.lockForConfiguration()
        currentCamera.activeFormat = format
        currentCamera.unlockForConfiguration()
        LocalDeviceFormat.addOrUpdateLocalDeviceFormatList(deviceFormat: .init(isDefaultCamera:
                                                                                true,
                                                                               selecedFormatIdentity: format.debugDescription.identity,
                                                                               deviceUniqueID: currentCamera.uniqueID))
    }
    
    var currentCameraFormat: Driver<(activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])?> {
        guard let currentCamera = self.currentCamera else {return .just(nil)}
        return .just((activeFormat: currentCamera.activeFormat,
                      supportFormats: currentCamera.formats))
    }
    
    init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }
    
    func initSetting() {
        guard !self.captureSession.isRunning else { return }

        // All AVCaptureSession operations must run on a background thread
        // to avoid blocking the main thread (UI unresponsiveness)
        recordingQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()
            if self.captureSession.canSetSessionPreset(.high) {
                self.captureSession.sessionPreset = .high
            }
            self.captureSession.commitConfiguration()

            let cameraDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            cameraDiscoverySession.devices.forEach {
                switch $0.position {
                case .back:  self.mainCamera  = $0
                case .front: self.innerCamera = $0
                default: break
                }
            }

            let audioDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified)
            self.currentAudio  = audioDiscoverySession.devices.first
            self.currentCamera = self.getUserDefaultCamera() ?? self.mainCamera

            do {
                let videoInput = try AVCaptureDeviceInput(device: self.currentCamera!)
                let audioInput = try AVCaptureDeviceInput(device: self.currentAudio!)

                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                }
                if self.captureSession.canAddInput(audioInput) {
                    self.captureSession.addInput(audioInput)
                }

                let videoDataOutput = AVCaptureVideoDataOutput()
                videoDataOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                ] as [String: Any]
                if self.captureSession.canAddOutput(videoDataOutput) {
                    self.captureSession.addOutput(videoDataOutput)
                }
                self.videoDataOutput = videoDataOutput

                let audioDataOutput = AVCaptureAudioDataOutput()
                audioDataOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
                if self.captureSession.canAddOutput(audioDataOutput) {
                    self.captureSession.addOutput(audioDataOutput)
                }
                self.audioDataOutput = audioDataOutput
            } catch {
                debugPrint(error)
            }

            self.captureSession.startRunning()
            self.selectUserDefaultFormat()
            // セッション起動後に一度だけ orientation を設定する
            // （録画開始時に変更するとパイプラインが停止するため、ここで済ませる）
            let orientation = UIDevice.current.orientation.AVCaptureVideoOrientation
            self.videoDataOutput?.connection(with: .video)?.videoOrientation = orientation
        }
    }
    
    func startRecording() {
        isCapturing = true
        timeOffset = .zero
        startTime = .zero
        currentRecordTime = 0
    }
    
    func stopRecording(completion: @escaping (() -> Void) = {}) {
        isCapturing = false
        recordingQueue.async {
            guard let recordEncoder = self.recordEncoder else {return }
            recordEncoder.finish(completionHandler: { [weak self] in
                guard let self = self else {return}
                self.startTime = .zero
                self.recordEncoder = nil
                do {
                    try PHPhotoLibrary.shared().performChangesAndWait({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: recordEncoder.pathUrl)
                        completion()
                    })
                } catch {
                    let e = error
                    debugPrint(e)
                }
                
            })
        }
        
    }
}

extension CaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isCapturing else {return}
        let isVideo = output === self.videoDataOutput
        
        if (recordEncoder == nil && !isVideo) {
            guard let fmt = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
            let desc = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)
            let samplerate = desc?.pointee.mSampleRate
            let channels = desc?.pointee.mChannelsPerFrame
            var videoSize = CGSize.init(width: 1280, height: 720)
            if let currentFormatDescription = currentCamera?.activeFormat.formatDescription {
                let dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription)
                // videoOrientation はここで変更しない（ライブ中の接続設定変更は
                // パイプラインを約1秒停止させ、録画冒頭が freeze する原因になる）
                videoSize = UIDevice.current.orientation.isLandscape ? .init(width: Int(dimensions.width), height: Int(dimensions.height)) : .init(width: Int(dimensions.height), height: Int(dimensions.width))
            }
            let isHDR = UserDefaults.standard.isHDRSwitch
            recordEncoder = try? CaptureEncoder(path: getUploadFilePath(),
                                                videoSize: videoSize,
                                                channels: Int(channels ?? 1),
                                                rate: samplerate ?? 44100,
                                                isHDR: isHDR)
        }
        var sampleBuffer: CMSampleBuffer = sampleBuffer
        if timeOffset.value > 0, let buffer = adjustTime(sample: sampleBuffer, offset: timeOffset){
            sampleBuffer = buffer
        }
        var pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let dur = CMSampleBufferGetDuration(sampleBuffer)
        
        if dur.value > 0 {
            pts = CMTimeAdd(pts, dur)
        }
        
        if isVideo {
            lastVideo = pts
        } else {
            lastAudio = pts
        }
        
        if self.startTime.value == 0 {
            self.startTime = dur
        }
        
        let sub = CMTimeSubtract(dur, self.startTime)
        self.currentRecordTime = CMTimeGetSeconds(sub)
        
        _ = recordEncoder?.encodeFrame(buffer: sampleBuffer, isVideo: isVideo)
    }
    
    private func getUploadFilePath() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let timeStr = formatter.string(from: .init())
        let fileName = "video\(timeStr).mp4"
        var isDir: ObjCBool = false
        let existed = FileManager.default.fileExists(atPath: cachePath, isDirectory: &isDir)
        if !(isDir.boolValue && existed) {
            try? FileManager.default.createDirectory(atPath: cachePath,
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)
        }
        return cachePath + "/" + fileName
    }
    
    static var cachePath: String {
        (NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                             .userDomainMask,
                                             true).first! as String) + "/videos"
    }
    
    private var cachePath: String {
        CaptureManager.cachePath
    }
    
    private func adjustTime(sample: CMSampleBuffer, offset: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sample,
                                               entryCount: 0,
                                               arrayToFill: nil,
                                               entriesNeededOut: &count)
        
        let pInfo = UnsafeMutablePointer<CMSampleTimingInfo>(bitPattern: MemoryLayout<CMSampleTimingInfo>.size * count)
        CMSampleBufferGetSampleTimingInfoArray(sample,
                                               entryCount: count,
                                               arrayToFill: pInfo,
                                               entriesNeededOut: &count)
        for i in 0..<count {
            guard let pInfo = pInfo else { continue }
            pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset)
            pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset)
        }
        var sout: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil,
                                              sampleBuffer: sample,
                                              sampleTimingEntryCount: count,
                                              sampleTimingArray: pInfo,
                                              sampleBufferOut: &sout)
        
        free(pInfo);
        return sout
    }
    
    func changeCamera(sourceView: UIView?) -> Driver<Bool> {
//        let willSetZoom = currentCamera!.videoZoomFactor + 0.3
//        if willSetZoom < currentCamera!.activeFormat.videoMaxZoomFactor {
//            try? currentCamera!.lockForConfiguration()
//            currentCamera?.ramp(toVideoZoomFactor: willSetZoom, withRate: 1)
//            currentCamera!.unlockForConfiguration()
//        }
//
//        print("!!!!!!!!!\(currentCamera!.virtualDeviceSwitchOverVideoZoomFactors)")
        
        return Observable<AVCaptureDevice>.create { observer in
            let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera], mediaType: .video, position: .unspecified).devices
            
            let alertController = UIAlertController(title: "カメラ選択",
                                                    message: nil, preferredStyle: .actionSheet)
            devices.enumerated().forEach { index, device in
                let action = UIAlertAction(title: device.japaneseDescription, style: .default) { _ in
                    observer.onNext(devices[index])
                    observer.onCompleted()
                }
                alertController.addAction(action)
            }
            alertController.addAction(.init(title: "cancel", style: .cancel, handler: nil))
            alertController.popoverPresentationController?.sourceView = sourceView
            UIViewController.rootViewController?.present(alertController, animated: true, completion: nil)
            return Disposables.create { alertController.dismiss(animated: true, completion: nil) }
        }.flatMap { device in
            Observable<Bool>.create { [weak self] observer in
                guard let self = self else {
                    observer.onNext(false)
                    return Disposables.create()
                }
                // Run all session operations on the dedicated background queue
                self.recordingQueue.async {
                    self.captureSession.stopRunning()
                    if let videoInput = self.captureSession.inputs.first(where: {
                        ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) ?? false
                    }) {
                        self.captureSession.removeInput(videoInput)
                    }
                    do {
                        let videoInput = try AVCaptureDeviceInput(device: device)
                        self.currentCamera = device
                        if self.captureSession.canAddInput(videoInput) {
                            self.captureSession.addInput(videoInput)
                        }
                    } catch {
                        observer.onError(error)
                        return
                    }
                    self.captureSession.startRunning()
                    self.selectUserDefaultFormat(isSave: true)
                    let orientation = UIDevice.current.orientation.AVCaptureVideoOrientation
                    self.videoDataOutput?.connection(with: .video)?.videoOrientation = orientation
                    observer.onNext(true)
                }
                return Disposables.create()
            }
        }.asDriver(onErrorJustReturn: false)
    }
    
    func selectUserDefaultFormat(isSave: Bool = false) {
        guard let currentCamera = self.currentCamera else {return}
        
        if let selectedFormatIdentity = LocalDeviceFormat.getLocalDeviceFormatList().first(where: {$0.deviceUniqueID == currentCamera.uniqueID})?.selecedFormatIdentity,
           let selectedFormat = currentCamera.formats.first(where: {$0.debugDescription.identity == selectedFormatIdentity}) {
            try? currentCamera.lockForConfiguration()
            currentCamera.activeFormat = selectedFormat
            currentCamera.unlockForConfiguration()
        }
        if isSave {
            LocalDeviceFormat.addOrUpdateLocalDeviceFormatList(deviceFormat: .init(isDefaultCamera:
                                                                                    true,
                                                                                   selecedFormatIdentity: currentCamera.activeFormat.debugDescription.identity,
                                                                                   deviceUniqueID: currentCamera.uniqueID))
        }
    }
    
    /// デバイス回転時に videoDataOutput の orientation を更新する
    /// 録画中に変更しても安全（パイプラインを停止させない）
    func updateVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        recordingQueue.async { [weak self] in
            self?.videoDataOutput?.connection(with: .video)?.videoOrientation = orientation
        }
    }

    /// 触摸对焦 + 曝光。devicePoint 为归一化坐标 (0–1)，由 captureDevicePointConverted 转换而来。
    func focus(at devicePoint: CGPoint) {
        guard let device = currentCamera else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {
            debugPrint("Focus error: \(error)")
        }
    }

    /// 被摄体变化时恢复连续自动对焦
    func resetFocusAndExposure() {
        guard let device = currentCamera else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = false
            device.unlockForConfiguration()
        } catch {
            debugPrint("Reset focus error: \(error)")
        }
    }

    func getUserDefaultCamera() -> AVCaptureDevice? {
        if let deviceUniqueID = LocalDeviceFormat.getLocalDeviceFormatList().first(where: {$0.isDefaultCamera})?.deviceUniqueID {
            
            let cameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTripleCamera, .builtInTelephotoCamera, .builtInDualWideCamera, .builtInUltraWideCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            let camera = cameraDiscoverySession.devices.first(where: {$0.uniqueID == deviceUniqueID})
            return camera
        }
        return nil
    }
}

// MARK: - Japanese natural language description for camera devices
private extension AVCaptureDevice {
    var japaneseDescription: String {
        switch (position, deviceType) {
        case (.front, _):
            return "フロントカメラ（自撮り・ビデオ通話向け）"
        case (.back, .builtInUltraWideCamera):
            return "超広角カメラ（風景・建物・広い空間を一枚に収める）"
        case (.back, .builtInWideAngleCamera):
            return "広角カメラ（標準的な撮影に最も適した万能レンズ）"
        case (.back, .builtInTelephotoCamera):
            return "望遠カメラ（遠くの被写体を光学ズームで撮影）"
        case (.back, .builtInDualCamera):
            return "デュアルカメラ・広角＋望遠（シーンに応じて自動切替）"
        case (.back, .builtInDualWideCamera):
            return "デュアルカメラ・超広角＋広角（シーンに応じて自動切替）"
        case (.back, .builtInTripleCamera):
            return "トリプルカメラ・超広角＋広角＋望遠（最も多彩な撮影が可能）"
        default:
            return localizedName
        }
    }
}

extension CaptureManager: AVCapturePhotoCaptureDelegate {
    // 撮影した画像データが生成されたときに呼び出されるデリゲートメソッド
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation() {
            // Data型をUIImageオブジェクトに変換
            let uiImage = UIImage(data: imageData)
            // 写真ライブラリに画像を保存
            UIImageWriteToSavedPhotosAlbum(uiImage!, nil,nil,nil)
        }
    }
}
