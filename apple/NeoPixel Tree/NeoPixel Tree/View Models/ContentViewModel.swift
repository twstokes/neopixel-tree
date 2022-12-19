//
//  ContentViewModel.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation

class ContentViewModel: ObservableObject {
    let udpClient = UDPClient(host: "tree.tannerstokes.com", port: "8733")
    private let transcriber: Transcriber

    @Published var runningTranscriber = false {
        didSet {
            if runningTranscriber {
                print("Running transcriber")
                startTranscriber()
            } else {
                print("Not running transcriber")
                stopTranscriber()
            }
        }
    }

    @Published var text = ""

    init() {
        udpClient.start()
        guard
            let modelPath = Bundle.main.path(forResource: "Whisper Models/ggml-tiny.en", ofType: "bin"),
            let transcriber = try? Transcriber(modelPath: modelPath)
        else {
            fatalError("Failed to load Whisper")
        }

        self.transcriber = transcriber
        transcriber.delegate = self
    }

    func colorChange(newColor: PixelColor) {
        udpClient.send(.fill_color(color: newColor))
    }

    func startTranscriber() {
        do {
            try transcriber.startCapturing()
        } catch {
            print("Error starting transcriber! \(error)")
        }
    }

    func stopTranscriber() {
        transcriber.stopCapturing()
    }
}

extension ContentViewModel: TranscriberDelegate {
    func receiveTranscribedText(text: String) {
        guard !text.isEmpty else {
            return
        }
        self.text = text
    }
}
