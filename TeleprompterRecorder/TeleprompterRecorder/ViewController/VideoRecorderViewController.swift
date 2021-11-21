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
    let viewModel = VideoRecorderViewModel(dependencies: .init(captureManager: CaptureManager(captureSession: AVCaptureSession())))
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
        
        bindViewModel()
    }
    
    private func bindViewModel() {
        let input = VideoRecorderViewModel.Input(ready: rx.viewWillAppear.flatMap({Driver.just(self.cameraPreviewLayer)}).asDriver(onErrorJustReturn: self.cameraPreviewLayer))

        let output = viewModel.transform(input: input)
        
        output.requestAuthorizationFailed.drive(onNext: { result in
            if !result {
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
