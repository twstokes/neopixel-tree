//
//  UDPClient.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation
import Network

struct UDPClient {
    private let connection: NWConnection
    private let maxPayload = 255

    private let udpQueue = DispatchQueue(label: "udpQueue", attributes: [], autoreleaseFrequency: .workItem)


    init(host: String, port: String) {
        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(port) else {
            fatalError("Invalid port defined.")
        }

        connection = NWConnection(host: nwHost, port: nwPort, using: .udp)
    }

    func start() {
        connection.start(queue: udpQueue)
    }

    func stop() {
        connection.cancel()
    }

    func send(_ command: Command) {
        let payload = UDPPayload(command: command)
        send(payload) { error in
            if let error = error {
                print("Error: \(error)")
            }
        }
    }

    private func send(_ payload: UDPPayload, completion: @escaping (Error?) -> Void) {
        let data = payload.toData()

        guard data.count <= maxPayload else {
            print("Error! Maximum payload would be exceeded when trying to send!")
            completion(UDPError.maxPayloadExceeded)
            return
        }

        connection.send(content: data, completion: .contentProcessed(completion))
    }
}

struct UDPPayload {
    let command: Int
    let values: [Int]

    init(command: Command) {
        self.command = command.id
        self.values = command.payload
    }

    func toData() -> Data {
        let uint8Values = values.map { UInt8($0) }
        return Data([UInt8(command)] + uint8Values)
    }
}

enum UDPError: Error {
    case maxPayloadExceeded
}
