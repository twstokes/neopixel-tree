//
//  WhisperStateInp.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/15/22.
//

import Foundation
import AVFoundation
import whisper

class WhisperState {
    var isCapturing = false
    var isTranscribing = false

    var queue: AudioQueueRef? = nil
    var dataFormat = AudioStreamBasicDescription(
        mSampleRate: Float64(WHISPER_SAMPLE_RATE),
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kLinearPCMFormatFlagIsSignedInteger,
        mBytesPerPacket: 2,
        mFramesPerPacket: 1,
        mBytesPerFrame: 2,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 16,
        mReserved: 0
    )

    var buffers: [AudioQueueBufferRef] = []
    var n_samples: UInt32 = 0
    var audioBufferI16: [Int16] = []
    var audioBufferF32: [Float] = []

    let ctx: OpaquePointer

    init(ctx: OpaquePointer) {
        self.ctx = ctx
    }
}
