//
//  Transcriber.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/15/22.
//

import Foundation
import AVFoundation
import whisper

typealias WhisperContext = OpaquePointer

class Transcriber {
    weak var delegate: TranscriberDelegate?

    private var isCapturing = false
    private var isTranscribing = false

    private let ctx: WhisperContext
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

        stopCapturing() // ensure state is reset before starting
        let newInputStatus = AudioQueueNewInput(
            &dataFormat,
            // C callback to process buffer data
            { inUserData, _, inBuffer, _, _, _ in
                guard let inUserData else {
                    return
                }

                let transcriber = Transcriber.fromPtr(inUserData)
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
            toMutablePtr(),
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

    private func transcribe(samples: [Float]) {
        guard !isTranscribing else {
            return
        }

        isTranscribing = true
        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let self else {
                return
            }

            guard whisper_full(
                self.ctx,
                WhisperConstants.params,
                samples,
                Int32(samples.count)
            ) == noErr
            else {
                self.delegate?.transcriptionError(error: TranscriberError.failedToRunWhisper)
                return
            }

            let result = (0..<whisper_full_n_segments(self.ctx))
                .compactMap {
                    guard let text = whisper_full_get_segment_text(self.ctx, $0) else {
                        return nil
                    }
                    return String(cString: text)
                }.reduce("", { $0 + $1 })

            guard self.isTranscribing else {
                // it's possible that transcribing was disabled
                // while the result was being computed
                return
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

extension Transcriber {
    static func fromPtr(_ ptr: UnsafeRawPointer) -> Transcriber {
        bridge(ptr: ptr)
    }

    func toMutablePtr() -> UnsafeMutableRawPointer {
        bridgeMutable(obj: self)
    }
}
