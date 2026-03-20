//
//  CaptureEncoder.swift
//  TeleprompterRecorder
//
//  Created by YanQi on 2021/11/22.
//

import Foundation
import AVFoundation

class CaptureEncoder {
    let writer: AVAssetWriter
    let pathUrl: URL
    
    let videoInput: AVAssetWriterInput
    let audioInput: AVAssetWriterInput
    
    init(path: String, videoSize: CGSize, channels: Int, rate: Float64, isHDR: Bool = false) throws {
        self.pathUrl = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(atPath: path)
        writer = try AVAssetWriter(outputURL: self.pathUrl, fileType: AVFileType.mp4)
        // moov アトムをファイル先頭に配置する（末尾だと Photos 再生時に
        // 先頭→末尾→先頭のシークが発生し冒頭1-2秒が停止して見える）
        writer.shouldOptimizeForNetworkUse = true

        // HDR: HEVC + 10bit  /  SDR: H.264 + 8bit
        // H.264 は HDR 色空間(HLG_BT2020)を保持できず、8bit 変換コストも大きい
        let videoCodec: AVVideoCodecType = isHDR ? .hevc : .h264
        var videoInputSettings: [String: Any] = [
            AVVideoCodecKey:   videoCodec,
            AVVideoWidthKey:   videoSize.width,
            AVVideoHeightKey:  videoSize.height,
        ]
        if isHDR {
            // HEVC で HDR 色空間・転送特性・色域を明示することで
            // Photos での正しい HDR 再生と初期フレームの処理遅延を防ぐ
            videoInputSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey:            AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey:          AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey:               AVVideoYCbCrMatrix_ITU_R_2020,
            ]
        }
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)
        
        let audioInputSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                          AVNumberOfChannelsKey: channels,
                                AVSampleRateKey: rate,
                            AVEncoderBitRateKey: 128000] as [String: Any]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioInputSettings)
        audioInput.expectsMediaDataInRealTime = true
        writer.add(audioInput)
    }
    
    func finish(completionHandler: @escaping () -> Void) {
        writer.finishWriting(completionHandler: completionHandler)
    }
    
    func encodeFrame(buffer: CMSampleBuffer, isVideo: Bool) -> Bool {
        guard buffer.dataReadiness == .ready else {return false}
        switch writer.status {
        case .unknown:
            // 最初のフレーム（音声・映像どちらでも）でセッションを開始する
            // 旧実装ではビデオフレームのみ対象だったため、エンコーダー生成の
            // トリガーになった最初のオーディオフレームが捨てられ、動画冒頭に
            // 音声の空白が生まれ停止して見える原因になっていた
            let startTime = CMSampleBufferGetPresentationTimeStamp(buffer)
            writer.startWriting()
            writer.startSession(atSourceTime: startTime)
        case .failed:
            debugPrint("encodeFrame: \(writer.error.debugDescription)")
            return false
        default:
            break
        }
        
        if isVideo {
            if videoInput.isReadyForMoreMediaData {
                return videoInput.append(buffer)
            }
        } else {
            if audioInput.isReadyForMoreMediaData {
                return audioInput.append(buffer)
            }
        }
        return false
    }
}
