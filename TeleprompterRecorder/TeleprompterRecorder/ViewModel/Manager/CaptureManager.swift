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
        
        captureSession.beginConfiguration()
        if (captureSession.canSetSessionPreset(.high)) {
            captureSession.sessionPreset = .high
        }
        captureSession.commitConfiguration()
        
        let cameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        cameraDiscoverySession.devices.forEach({
            switch $0.position {
            case .back:
                self.mainCamera = $0
            case .front:
                self.innerCamera = $0
            default:
                break
            }
        })
        
        let audioDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified)
        currentAudio = audioDiscoverySession.devices.first;
        
        // 起動時のカメラを設定
        currentCamera = getUserDefaultCamera() ?? mainCamera
        
        do {
            /*
             // 指定したデバイスを使用するために入力を初期化
             let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
             // 指定した入力をセッションに追加
             session.addInput(captureDeviceInput)
             // 出力データを受け取るオブジェクトの作成
             photoOutput = AVCapturePhotoOutput()
             // 出力ファイルのフォーマットを指定
             photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
             session.addOutput(photoOutput!)
             let settings = AVCapturePhotoSettings()
             // フラッシュの設定
             settings.flashMode = .auto
             // 撮影された画像をdelegateメソッドで処理
             self.photoOutput?.capturePhoto(with: settings, delegate: self)
             */
            
            let videoInput = try AVCaptureDeviceInput(device: currentCamera!)
            
            let audioInput = try AVCaptureDeviceInput(device: currentAudio!)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ] as [String : Any]
            self.captureSession.addOutput(videoDataOutput)
            self.videoDataOutput = videoDataOutput
            
            let audioDataOutput = AVCaptureAudioDataOutput()
                audioDataOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
                self.captureSession.addOutput(audioDataOutput)
            self.audioDataOutput = audioDataOutput
            
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            }
            
            if captureSession.canAddOutput(audioDataOutput) {
                captureSession.addOutput(audioDataOutput)
            }
            
            
        } catch {
            debugPrint(error)
        }
        try? FileManager.default.removeItem(atPath: cachePath)
        self.captureSession.startRunning()
        selectUserDefaultFormat()
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
                try? PHPhotoLibrary.shared().performChangesAndWait({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: recordEncoder.pathUrl)
                    completion()
                })
                
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
                
                videoDataOutput?.connection(with: .video)?.videoOrientation = UIDevice.current.orientation.AVCaptureVideoOrientation
                videoSize = UIDevice.current.orientation.isLandscape ? .init(width: Int(dimensions.width), height: Int(dimensions.height)) : .init(width: Int(dimensions.height), height: Int(dimensions.width))
            }
            recordEncoder = try? CaptureEncoder(path: getUploadFilePath(),
                                           videoSize: videoSize,
                                           channels: Int(channels ?? 1),
                                           rate: samplerate ?? 44100)
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
    
    private var cachePath: String {
        (NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                                .userDomainMask,
                                                            true).first! as String) + "/videos"
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
    
    func changeCamera() throws -> Bool {
        guard let currentCamera = self.currentCamera else {return false}
        captureSession.stopRunning()
        
        let isFront = currentCamera == innerCamera
        if let videoInput = captureSession.inputs.first(where: {($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) ?? false}) {
            captureSession.removeInput(videoInput)
        }
        var videoInput: AVCaptureDeviceInput?
        if isFront {
            videoInput = try AVCaptureDeviceInput(device: mainCamera!)
            self.currentCamera = mainCamera
        } else {
            videoInput = try AVCaptureDeviceInput(device: innerCamera!)
            self.currentCamera = innerCamera
        }
        if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return false
        }
        captureSession.startRunning()
        selectUserDefaultFormat(isSave: true)
        
        return true
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
    
    func getUserDefaultCamera() -> AVCaptureDevice? {
        if let deviceUniqueID = LocalDeviceFormat.getLocalDeviceFormatList().first(where: {$0.isDefaultCamera})?.deviceUniqueID {
            
            let cameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTripleCamera, .builtInTelephotoCamera, .builtInDualWideCamera, .builtInDualWideCamera, .builtInUltraWideCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            let camera = cameraDiscoverySession.devices.first(where: {$0.uniqueID == deviceUniqueID})
            return camera
        }
        return nil
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
