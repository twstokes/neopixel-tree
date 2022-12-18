//
//  WhisperConstants.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/17/22.
//

import Foundation
import AVFoundation

struct WhisperConstants {
    static let maxBuffers = 3
    static let maxAudioSec = 10
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
}
