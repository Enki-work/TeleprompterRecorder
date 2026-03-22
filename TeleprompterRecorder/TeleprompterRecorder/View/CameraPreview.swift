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

    // 触摸对焦指示器
    private let focusIndicator: UIView = {
        let v = UIView()
        v.layer.borderColor = UIColor.systemYellow.cgColor
        v.layer.borderWidth = 1.5
        v.backgroundColor = .clear
        v.alpha = 0
        v.isUserInteractionEnabled = false
        return v
    }()

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    init() {
        captureButtonsView = CaptureButtonsView(frame: UIScreen.main.bounds)
        super.init(frame: UIScreen.main.bounds)
        captureButtonsView.frame = UIScreen.main.bounds
        self.cameraPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        cameraPreviewLayer.connection?.videoOrientation = UIWindow.orientation.AVCaptureVideoOrientation
        self.addSubview(captureButtonsView)
        self.addSubview(focusIndicator)  // 叠在最上层
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 在指定位置显示对焦框动画
    func showFocusIndicator(at point: CGPoint) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideFocusIndicator), object: nil)
        let size: CGFloat = 72
        focusIndicator.frame = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        focusIndicator.alpha = 1
        focusIndicator.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        UIView.animate(withDuration: 0.15) {
            self.focusIndicator.transform = .identity
        }
        perform(#selector(hideFocusIndicator), with: nil, afterDelay: 1.5)
    }

    @objc private func hideFocusIndicator() {
        UIView.animate(withDuration: 0.3) { self.focusIndicator.alpha = 0 }
    }
}
