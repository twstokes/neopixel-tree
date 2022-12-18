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
    private var isCapturing = false
    private var isTranscribing = false

    private let ctx: OpaquePointer
    private var queue: AudioQueueRef?

    private var audioQueueBuffers: [AudioQueueBufferRef] = []
    private var sampleBuffer: [Float] = []

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

    init?(modelPath: String) {
        guard let ctx = whisper_init(modelPath) else {
            return nil
        }
        self.ctx = ctx
    }

    deinit {
        whisper_free(ctx)
    }

    func stopCapturing() {
        isCapturing = false

        guard let queue = queue else {
            print("Failed to get queue when stopping")
            return
        }

        AudioQueueStop(queue, true)
        for buffer in audioQueueBuffers {
            AudioQueueFreeBuffer(queue, buffer)
        }
        AudioQueueDispose(queue, true)
    }

    func toggleCapture() {
        if isCapturing {
            print("Stopping capturing")
            stopCapturing()
            return
        }

        print("Starting capturing")

        sampleBuffer.removeAll()

        let status = AudioQueueNewInput(
            &dataFormat,
            // C callback to process buffer data
            { inUserData, _, inBuffer, _, _, _ in
                guard let inUserData else {
                    print("inUserData was nil!")
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
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            nil,
            nil,
            0,
            &queue
        )

        guard let queue else {
            print("No queue!")
            return
        }

        if status == noErr {
            for _ in 0..<WhisperConstants.maxBuffers {
                var buffer: AudioQueueBufferRef? = nil
                AudioQueueAllocateBuffer(queue, UInt32(WhisperConstants.bytesPerBuffer), &buffer)
                AudioQueueEnqueueBuffer(queue, buffer!, 0, nil)
                if let buffer {
                    audioQueueBuffers.append(buffer)
                }
            }

            isCapturing = true
            let status = AudioQueueStart(queue, nil)
            if status == 0 {
                print("Capturing")
            }
        } else {
            stopCapturing()
        }

    }

    private func transcribe() {
        guard !isTranscribing else {
            return
        }

        isTranscribing = true

        DispatchQueue.global(qos: .default).async {
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.print_progress = false
            params.print_timestamps = true
            params.n_threads = Int32(min(8, ProcessInfo.processInfo.processorCount))
            params.no_context = true
            params.single_segment = true // true == real time

            if whisper_full(self.ctx, params, self.sampleBuffer, Int32(self.sampleBuffer.count)) != 0 {
                print("Failed to run the model")
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
                if !result.isEmpty {
                    print(result)
                }
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
