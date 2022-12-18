//
//  TranscriberError.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/18/22.
//

import Foundation

enum TranscriberError: Error {
    /// tried to start capture while one was running
    case captureInProgress
    /// couldn't initialize Whisper
    case failedToInit
    /// Whisper failed to run
    case failedToRunWhisper
    /// no audio queue was available
    case noAudioQueue
    /// audio queue buffers were expected
    case noAudioQueueBuffers
}

enum AudioQueueError: Error {
    case allocateBufferFailed
    case bufferCreationFailed
    case enqueueBufferFailed
    case inputCreationFailed
    case startFailed
}
