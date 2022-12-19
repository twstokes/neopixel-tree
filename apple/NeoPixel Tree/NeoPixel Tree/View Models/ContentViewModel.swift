//
//  ContentViewModel.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation
import UIKit

class ContentViewModel: ObservableObject {
    let udpClient = UDPClient(host: "tree.tannerstokes.com", port: "8733")
    private let transcriber: Transcriber

    // we have to be a little bit clever on the client side
    // to debounce commands to the tree
    private var lastPayloadSent: (payload: [Int], date: Date)?

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

    func rainbowMode() {
        udpClient.send(.rainbow(repeat: false))
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

    func detectA8C(from text: String) {
        let colors = [
            ("wordpress", PixelColor(r: 0, g: 96, b: 136)),
            ("word press", PixelColor(r: 0, g: 96, b: 136)),
            ("jetpack", PixelColor(r: 6, g: 158, b: 8)),
            ("jet pack", PixelColor(r: 6, g: 158, b: 8))
        ]

        let detectedColor = colors.filter { text.lowercased().contains($0.0.lowercased()) }.first
        if let detectedColor {
            self.text = "Detected: \(detectedColor.0)"
            let command = Command.theater_chase(repeat: false, color: detectedColor.1)
            sendCommandWithDebouncing(command: command)
        }
    }

    func sendCommandWithDebouncing(command: Command) {
        let debounceDelaySeconds = 10.0

        if
            let lastPayloadSent,
            lastPayloadSent.payload == command.payload,
            Date.now.timeIntervalSince1970 - lastPayloadSent.date.timeIntervalSince1970 < debounceDelaySeconds
        {
            return
        }

        self.lastPayloadSent = (payload: command.payload, date: .now)
        udpClient.send(command)
    }

    func detectColor(from text: String) {
        let colors = [
            ("red", PixelColor.init(r: 255, g: 0, b: 0)),
            ("blue", PixelColor.init(r: 0, g: 0, b: 255)),
            ("green", PixelColor.init(r: 0, g: 255, b: 0))
        ]

        let detectedColor = colors.filter { text.lowercased().contains($0.0.lowercased()) }.first
        if let detectedColor {
            self.text = "Detected: \(detectedColor.0)"
            udpClient.send(.fill_color(color: detectedColor.1))
        }
    }

    var stillRainbowCommand: Command {
        let colors = (0..<106)
            .map { $0 * 2 }
            .map { UIColor(hue: CGFloat($0) / 255, saturation: 1, brightness: 1, alpha: 1).toPixelColor() }
        return Command.fill_pattern(colors: colors)
    }

    func sendStillRainbow() {
        udpClient.send(stillRainbowCommand)
    }
}

extension ContentViewModel: TranscriberDelegate {
    func receiveTranscribedText(text: String) {
        guard !text.isEmpty else {
            return
        }

        detectA8C(from: text)
        if
            let lastPayloadSent = lastPayloadSent?.payload,
            lastPayloadSent == stillRainbowCommand.payload
        {
            // don't keep blasting with the same command
            return
        }

        sendStillRainbow()
    }
}
