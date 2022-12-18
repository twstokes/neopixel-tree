//
//  Whisper.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/15/22.
//

import Foundation
import AVFoundation
import whisper

class Whisper {
    let path = Bundle.main.path(forResource: "ggml-base.en", ofType: "bin")
    var state: WhisperState

    static let num_buffers = 3
    static let max_audio_sec = 300
    static let sample_rate = 16000
    static let num_bytes_per_buffer = 16*1024



    init() {
        guard let path else {
            fatalError("Bad path!")
        }

        guard let ctx = whisper_init(path) else {
            fatalError("Failed to init!")
        }

        state = WhisperState(ctx: ctx)
    }

    deinit {
        whisper_free(state.ctx)
    }

    func stopCapturing() {
        state.isCapturing = false

        guard let queue = state.queue else {
            print("Failed to get queue when stopping")
            return
        }

        AudioQueueStop(queue, true)
        for buffer in state.buffers {
            AudioQueueFreeBuffer(queue, buffer)
        }
        AudioQueueDispose(queue, true)
    }

    func toggleCapture() {
        if state.isCapturing {
            print("Stopping capturing")
            stopCapturing()
            return
        }

        print("Starting capturing")

        state.n_samples = 0

        let status = AudioQueueNewInput(
            &state.dataFormat,
            // C callback to process buffer data
            { inUserData, _, inBuffer, _, _, _ in
                guard let inUserData else {
                    print("inUserData was nil!")
                    return
                }

                let whisper = Unmanaged<Whisper>.fromOpaque(inUserData).takeUnretainedValue()
                whisper.processRawAudioBuffer(inBuffer)
            },
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            nil,
            nil,
            0,
            &state.queue
        )

        guard let queue = state.queue else {
            print("No queue!")
            return
        }

        if status == noErr {
            for _ in 0..<Self.num_buffers {
                var buffer: AudioQueueBufferRef? = nil
                AudioQueueAllocateBuffer(queue, UInt32(Whisper.num_bytes_per_buffer), &buffer)
                AudioQueueEnqueueBuffer(queue, buffer!, 0, nil)
                if let buffer {
                    state.buffers.append(buffer)
                }
            }

            state.isCapturing = true
            let status = AudioQueueStart(queue, nil)
            if status == 0 {
                print("Capturing")
            }
        } else {
            stopCapturing()
        }

    }

    func onTranscribe() {
        guard !state.isTranscribing else {
            return
        }

        state.isTranscribing = true

        DispatchQueue.global(qos: .default).async {
            self.state.audioBufferF32 = self.state.audioBufferI16.map { Float($0) / 32768.0 }

            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            let max_threads = min(8, ProcessInfo.processInfo.processorCount)

            params.print_realtime = false
            params.print_progress = false
            params.print_timestamps = true
            params.print_special = false
            params.translate = false
            //        params.language = "en"
            params.n_threads = Int32(max_threads)
            params.offset_ms = 0
            params.no_context = true
            params.single_segment = true // true == real time

            //            let startTime = CACurrentMediaTime()

            whisper_reset_timings(self.state.ctx)
            if whisper_full(self.state.ctx, params, self.state.audioBufferF32, Int32(self.state.n_samples)) != 0 {
                print("Failed to run the model")
                return
            }

            //            whisper_print_timings(self.stateInp.ctx)
            //            let endTime = CACurrentMediaTime()

            let n_segments = whisper_full_n_segments(self.state.ctx)

            var result = ""

            for i in 0..<n_segments {
                if let text = whisper_full_get_segment_text(self.state.ctx, i) {
                    result += String(cString: text)
                }
            }

            DispatchQueue.main.async {
                print(result)
                self.state.isTranscribing = false
            }
        }
    }

    func processSamples(_ samples: [Int16]) {
        guard state.isCapturing else {
            return
        }

        guard samples.count + Int(state.n_samples) < Self.max_audio_sec * Self.sample_rate else {
            print("Too much audio - ignoring")

            DispatchQueue.main.async {
                self.stopCapturing()
            }
            return
        }

        state.audioBufferI16 += samples
        state.n_samples += UInt32(samples.count)

        onTranscribe()
    }

    func processRawAudioBuffer(_ inBuffer: AudioQueueBufferRef) {
        let audioBuffer = inBuffer.pointee
        /// Divide by two for Int16
        let numSamples = Int(audioBuffer.mAudioDataByteSize / 2)

        /// Get an array of Int16s from the mAudioData pointer
        let int16Ptr = audioBuffer.mAudioData.bindMemory(to: Int16.self, capacity: numSamples)
        let audioBufferData = UnsafeBufferPointer(start: int16Ptr, count: numSamples)
        let samples = Array(audioBufferData)

        if let queue = state.queue {
            AudioQueueEnqueueBuffer(queue, inBuffer, 0, nil)
        }

        DispatchQueue.main.async { [weak self] in
            self?.processSamples(samples)
        }
    }

}
