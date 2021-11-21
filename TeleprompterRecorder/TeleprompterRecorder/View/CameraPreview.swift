//
//  CameraPreview.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/21.
//

import UIKit
import AVFoundation

class CameraPreview: UIView {
    
    // プレビュー表示用のレイヤ
    var cameraPreviewLayer : AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    init() {
        super.init(frame: .zero)
        // プレビューレイヤが、カメラのキャプチャーを縦横比を維持した状態で、表示するように設定
        self.cameraPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        // プレビューレイヤの表示の向きを設定
        self.cameraPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
