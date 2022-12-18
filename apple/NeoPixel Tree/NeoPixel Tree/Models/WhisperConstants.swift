//
//  WhisperConstants.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/17/22.
//

import Foundation
import AVFoundation
import whisper

struct WhisperConstants {
    static let maxBuffers = 3
    static let maxAudioSec = 30
    static let sampleRate = 16000
    static let bytesPerBuffer = 16*1024
    static let maxSamples = maxAudioSec * sampleRate

    static let dataFormat = AudioStreamBasicDescription(
        mSampleRate: Float64(WhisperConstants.sampleRate),
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kLinearPCMFormatFlagIsSignedInteger,
        mBytesPerPacket: 2,
        mFramesPerPacket: 1,
        mBytesPerFrame: 2,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 16,
        mReserved: 0
    )

    static let params: whisper_full_params = {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_timestamps = true
        params.n_threads = Int32(min(8, ProcessInfo.processInfo.processorCount))
        params.no_context = true
        params.single_segment = true // real time
        return params
    }()
}
