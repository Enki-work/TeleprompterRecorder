//
//  FormatListViewModel.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/23.
//

import RxSwift
import RxCocoa
import UIKit
import AVFoundation

final class FormatListViewModel: ViewModelType {
    
    struct Input {
        let formats: Driver<(activeFormat: AVCaptureDevice.Format, supportFormats: [AVCaptureDevice.Format])>
    }
    
    struct Output {
        let datas: Driver<[MySection]>
    }
    
    func transform(input: Input) -> Output {
        
        let datas = input.formats.flatMap({ formats -> Driver<[MySection]>in
            Driver<[MySection]>.just(Array(Set(formats.supportFormats.compactMap({
                let dims = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                return "\(dims.width)x\(dims.height)"
            }) as [String])).compactMap({ dimsString in
                MySection(header: dimsString, items: formats.supportFormats.filter({
                    let dims = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                    return "\(dims.width)x\(dims.height)" == dimsString
                }))
            }).sorted(by: {$0.dimensionsWidth >= $1.dimensionsWidth}))
        })
        
        return Output(datas: datas)
    }
}
