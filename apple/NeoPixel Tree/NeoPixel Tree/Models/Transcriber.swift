//
//  Transcriber.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/15/22.
//

import Foundation
import AVFoundation
import whisper


class Transcriber {
    var delegate: TranscriberDelegate?

    private var isCapturing = false
    private var isTranscribing = false

    /// `whisper_context` struct
    private let ctx: OpaquePointer
    private var queue: AudioQueueRef?

    private var audioQueueBuffers: [AudioQueueBufferRef] = []
    private var sampleBuffer: [Float] = []

    private var dataFormat = WhisperConstants.dataFormat

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

        if let queue {
            AudioQueueStop(queue, true)
            audioQueueBuffers.forEach { AudioQueueFreeBuffer(queue, $0) }
            AudioQueueDispose(queue, true)
        }

        self.queue = nil
        sampleBuffer.removeAll()
        audioQueueBuffers.removeAll()
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

                let transcriber: Transcriber = bridge(ptr: inUserData)
                let samples = Transcriber.samplesFromAudioQueueBufferRef(inBuffer)
                transcriber.processSamples(samples)

                guard
                    let queue = transcriber.queue,
                    AudioQueueEnqueueBuffer(queue, inBuffer, 0, nil) != noErr
                else {
                    transcriber.delegate?.transcriptionError(error: AudioQueueError.enqueueBufferFailed)
                    return
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
            throw AudioQueueError.inputCreationFailed
        }

        guard let queue else {
            throw TranscriberError.noAudioQueue
        }

        try audioQueueBuffers = (0..<WhisperConstants.maxBuffers)
            .compactMap { _ in
                var buffer: AudioQueueBufferRef?
                guard
                    AudioQueueAllocateBuffer(queue, UInt32(WhisperConstants.bytesPerBuffer), &buffer) == noErr,
                    let buffer
                else {
                    throw AudioQueueError.allocateBufferFailed
                }
                guard AudioQueueEnqueueBuffer(queue, buffer, 0, nil) == noErr else {
                    throw AudioQueueError.enqueueBufferFailed
                }
                return buffer
            }

        guard !audioQueueBuffers.isEmpty else {
            throw TranscriberError.noAudioQueueBuffers
        }

        guard AudioQueueStart(queue, nil) == noErr else {
            throw AudioQueueError.startFailed
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

    private func transcribe(samples: [Float]) {
        guard !isTranscribing else {
            return
        }

        isTranscribing = true
        DispatchQueue.global(qos: .default).async {
            let whisperStatus = whisper_full(self.ctx, Self.whisperParams, samples, Int32(samples.count))

            guard whisperStatus == noErr else {
                self.delegate?.transcriptionError(error: TranscriberError.failedToRunWhisper)
                return
            }

            let result = (0..<whisper_full_n_segments(self.ctx))
                .compactMap { i in
                    guard let text = whisper_full_get_segment_text(self.ctx, i) else {
                        return nil
                    }
                    return String(cString: text)
                }.reduce("", { $0 + $1 })

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

        transcribe(samples: sampleBuffer)
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
