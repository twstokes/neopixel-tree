//
//  Transcriber.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/15/22.
//

import Foundation
import AVFoundation
import whisper

enum TranscriberError: Error {
    case failedToInit
    case captureInProgress
    case audioQueueCreationFailure
    case noAudioQueue
    case failedToStartAudioQueue
    case failedToRunWhisper
    case noAudioQueueBuffers
}

class Transcriber {
    private var isCapturing = false
    private var isTranscribing = false

    /// `whisper_context` struct
    private let ctx: OpaquePointer
    private var queue: AudioQueueRef?

    private var audioQueueBuffers: [AudioQueueBufferRef] = []
    private var sampleBuffer: [Float] = []

    var delegate: TranscriberDelegate?

    private var dataFormat = AudioStreamBasicDescription(
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

    init(modelPath: String) throws {
        guard let ctx = whisper_init(modelPath) else {
            throw TranscriberError.failedToInit
        }
        self.ctx = ctx
    }

    deinit {
        whisper_free(ctx)
    }

    func stopCapturing() {
        isCapturing = false
        isTranscribing = false

        defer {
            sampleBuffer.removeAll()
            audioQueueBuffers.removeAll()
            self.queue = nil
        }

        guard let queue else {
            return
        }

        AudioQueueStop(queue, true)
        audioQueueBuffers.forEach { AudioQueueFreeBuffer(queue, $0) }
        AudioQueueDispose(queue, true)
    }

    func startCapturing() throws {
        guard !isCapturing else {
            throw TranscriberError.captureInProgress
        }

        stopCapturing() // ensure buffers are removed
        let newInputStatus = AudioQueueNewInput(
            &dataFormat,
            // C callback to process buffer data
            { inUserData, _, inBuffer, _, _, _ in
                guard let inUserData else {
                    return
                }

                let whisper: Transcriber = bridge(ptr: inUserData)
                let samples = Transcriber.samplesFromAudioQueueBufferRef(inBuffer)

                if let queue = whisper.queue {
                    AudioQueueEnqueueBuffer(queue, inBuffer, 0, nil)
                }

                DispatchQueue.main.async { [weak whisper] in
                    whisper?.processSamples(samples)
                }
            },
            bridgeMutable(obj: self),
            nil,
            nil,
            0,
            &queue
        )

        guard newInputStatus == noErr else {
            stopCapturing() // called to reset queue and buffers
            throw TranscriberError.audioQueueCreationFailure
        }

        guard let queue else {
            throw TranscriberError.noAudioQueue
        }

        audioQueueBuffers = (0..<WhisperConstants.maxBuffers)
            .compactMap { _ in
                var buffer: AudioQueueBufferRef?
                AudioQueueAllocateBuffer(queue, UInt32(WhisperConstants.bytesPerBuffer), &buffer)
                guard let buffer else {
                    return nil
                }

                AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
                return buffer
            }

        guard !audioQueueBuffers.isEmpty else {
            throw TranscriberError.noAudioQueueBuffers
        }

        guard AudioQueueStart(queue, nil) == noErr else {
            throw TranscriberError.failedToStartAudioQueue
        }

        isCapturing = true
    }

    private static var whisperParams: whisper_full_params {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_timestamps = true
        params.n_threads = Int32(min(8, ProcessInfo.processInfo.processorCount))
        params.no_context = true
        params.single_segment = true // true == real time
        return params
    }

    private func transcribe() {
        guard !isTranscribing else {
            return
        }

        isTranscribing = true

        DispatchQueue.global(qos: .default).async {
            let whisperStatus = whisper_full(self.ctx, Self.whisperParams, self.sampleBuffer, Int32(self.sampleBuffer.count))

            guard whisperStatus == noErr else {
                self.delegate?.transcriptionError(error: .failedToRunWhisper)
                return
            }

            let n_segments = whisper_full_n_segments(self.ctx)
            var result = ""

            for i in 0..<n_segments {
                if let text = whisper_full_get_segment_text(self.ctx, i) {
                    result += String(cString: text)
                }
            }

            DispatchQueue.main.async {
                self.delegate?.receiveTranscribedText(text: result)
                self.isTranscribing = false
            }
        }
    }

    private func processSamples(_ samples: [Float]) {
        guard isCapturing else {
            return
        }

        sampleBuffer += samples

        if sampleBuffer.count > WhisperConstants.maxSamples {
            let diff = self.sampleBuffer.count - WhisperConstants.maxSamples
            sampleBuffer = Array(sampleBuffer.dropFirst(diff))
        }

        transcribe()
    }

    /// Returns an array of samples from an Audio Queue buffer ref
    private static func samplesFromAudioQueueBufferRef(_ buffer: AudioQueueBufferRef) -> [Float] {
        let audioBuffer = buffer.pointee
        /// Divide by two for Int16
        let numSamples = Int(audioBuffer.mAudioDataByteSize / 2)
        /// Get an array of Int16s from the mAudioData pointer
        let int16Ptr = audioBuffer.mAudioData.bindMemory(to: Int16.self, capacity: numSamples)
        let audioBufferData = UnsafeBufferPointer(start: int16Ptr, count: numSamples)
        return Array(audioBufferData).map { Float($0) / 32768.0 }
    }
}
