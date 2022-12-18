//
//  TranscriberDelegate.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/18/22.
//

import Foundation

protocol TranscriberDelegate: AnyObject {
    func receiveTranscribedText(text: String)
    func transcriptionError(error: Error)
}

extension TranscriberDelegate {
    func transcriptionError(error: Error) {
        return
    }
}
