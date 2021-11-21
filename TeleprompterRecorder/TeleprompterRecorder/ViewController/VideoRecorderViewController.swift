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
import Photos

class VideoRecorderViewController: UIViewController {
    
    // メインカメラの管理オブジェクトの作成
    var mainCamera: AVCaptureDevice?
    // インカメの管理オブジェクトの作成
    var innerCamera: AVCaptureDevice?
    // 現在使用しているカメラデバイスの管理オブジェクトの作成
    var currentCamera: AVCaptureDevice?
    // 現在使用しているカメラデバイスの管理オブジェクトの作成
    var currentAudio: AVCaptureDevice?
    
    // キャプチャーの出力データを受け付けるオブジェクト
    var photoOutput : AVCapturePhotoOutput?
    // プレビュー表示用のレイヤ
    var cameraPreviewLayer : AVCaptureVideoPreviewLayer {
        (view as! CameraPreview).layer as! AVCaptureVideoPreviewLayer
    }
    
    let disposeBag = DisposeBag()
    
    
    override func loadView() {
        self.view = CameraPreview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        if (session.canSetSessionPreset(.high)) {
            session.sessionPreset = .high
        }
        session.commitConfiguration()
        
        
        NotificationCenter.default.rx.notification(NSNotification.Name.AVCaptureSessionRuntimeError).take(until: self.rx.deallocated).subscribe { notification in
            debugPrint("AVCaptureSessionRuntimeError")
        }.disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(NSNotification.Name.AVCaptureDeviceWasDisconnected).take(until: self.rx.deallocated).subscribe { notification in
            debugPrint("AVCaptureDeviceWasDisconnected")
        }.disposed(by: disposeBag)
        
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
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
            
        } catch {
            debugPrint(error)
        }
        
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
        }).subscribe(onSuccess: { result in
            if result {
                self.cameraPreviewLayer.session = session
                session.startRunning()
            } else {
                UIAlertController.showTwoBtnAlert(title: "アプリ正常に使用するのに必要の権限オンにしてください", secondBtnTitle: "設定画面へ") { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
        }).disposed(by: disposeBag)
    }
}

extension VideoRecorderViewController: AVCapturePhotoCaptureDelegate {
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
