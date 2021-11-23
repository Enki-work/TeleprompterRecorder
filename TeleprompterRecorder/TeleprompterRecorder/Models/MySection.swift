//
//  MySection.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/23.
//

import RxSwift
import RxDataSources
import AVFoundation

struct MySection {
    var header: String
    var items: [AVCaptureDevice.Format]
}

extension MySection: AnimatableSectionModelType {
    
    var identity: String {
        return header
    }
    
    var dimensionsWidth: Int32 {
        guard let first = items.first else {return 0}
        return CMVideoFormatDescriptionGetDimensions(first.formatDescription).width
    }
    
    init(original: MySection, items: [AVCaptureDevice.Format]) {
        self = original
        self.items = items
    }
}

extension AVCaptureDevice.Format: IdentifiableType {
    public var identity: String {
        return self.debugDescription.identity
    }
}
