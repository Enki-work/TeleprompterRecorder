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
    
    let captureButtonsView: CaptureButtonsView
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    init() {
        captureButtonsView = UINib(nibName: "CaptureButtonsView", bundle: nil)
                    .instantiate(withOwner: nil, options: nil)
                    .first as! CaptureButtonsView
        super.init(frame: UIScreen.main.bounds)
        captureButtonsView.frame = UIScreen.main.bounds
        // プレビューレイヤが、カメラのキャプチャーを縦横比を維持した状態で、表示するように設定
        self.cameraPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        self.addSubview(captureButtonsView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
