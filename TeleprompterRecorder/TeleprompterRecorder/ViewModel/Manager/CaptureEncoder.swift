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
    
    init(path: String, videoSize: CGSize, channels: Int, rate: Float64) throws {
        self.pathUrl = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(atPath: path)
        writer = try AVAssetWriter(outputURL: self.pathUrl, fileType: AVFileType.mp4)
        writer.shouldOptimizeForNetworkUse = false
        
        let videoInputSettings = [AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoWidthKey: videoSize.width,
                       AVVideoHeightKey: videoSize.height] as [String: Any]
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
            if isVideo {
                let startTime = CMSampleBufferGetPresentationTimeStamp(buffer)
                writer.startWriting()
                writer.startSession(atSourceTime: startTime)
            }
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
