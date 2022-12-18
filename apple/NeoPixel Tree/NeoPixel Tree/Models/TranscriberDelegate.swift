//
//  TranscriberDelegate.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/18/22.
//

import Foundation

protocol TranscriberDelegate {
    func receiveTranscribedText(text: String)
    func transcriptionError(error: TranscriberError)
}

extension TranscriberDelegate {
    func transcriptionError(error: TranscriberError) {
        return
    }
}
