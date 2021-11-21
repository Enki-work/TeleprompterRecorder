//
//  CaptureManager.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/21.
//

import AVFoundation
import Photos
import UIKit

class CaptureManager: NSObject {
    let captureSession: AVCaptureSession
    
    
    // メインカメラの管理オブジェクトの作成
    private var mainCamera: AVCaptureDevice?
    // インカメの管理オブジェクトの作成
    private var innerCamera: AVCaptureDevice?
    // 現在使用しているカメラデバイスの管理オブジェクトの作成
    private var currentCamera: AVCaptureDevice?
    // 現在使用しているカメラデバイスの管理オブジェクトの作成
    private var currentAudio: AVCaptureDevice?
    
    // キャプチャーの出力データを受け付けるオブジェクト
    private var photoOutput : AVCapturePhotoOutput?
    
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
        currentCamera = mainCamera

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
            currentCamera?.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)

            let videoInput = try AVCaptureDeviceInput(device: currentCamera!)

            let audioInput = try AVCaptureDeviceInput(device: currentAudio!)

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }

        } catch {
            debugPrint(error)
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
