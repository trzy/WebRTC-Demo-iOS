//
//  SignalTransport.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//

import Combine
import Foundation
import Starscream

class SignalTransport: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var message: Message?

    private let _ws: WebSocket

    init() {
        let url = URL(string: "ws://192.168.0.128:8000/ws")!
        _ws = WebSocket(request: URLRequest(url: url))
        _ws.delegate = self
        _ws.connect()
    }

    /// Send a message to peers via the signaling transport.
    /// - Parameter message: The JSON-encoded message to send.
    func send(_ message: String) {
        _ws.write(string: message)
    }
}

extension SignalTransport: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(_):
            print("[SignalTransport] WebSocket connected")
            let hello = HelloMessage(message: "Hello from iOS!")
            _ws.write(string: hello.toJSON())
            isConnected = true

        case .text(let string):
            print("[SignalTransport] Received message: \(string)")

            if let message = Message.decode(from: string) {
                switch (message) {
                case .hello(let message):
                    // This is just an informational message, so we intercept it here
                    print("[SignalTransport] Peer said hello: \(message.message)")
                default:
                    // Forward the rest to the listener
                    self.message = message
                }
            } else {
                print("[SignalTransport] Ignoring unknown message")
            }

        case .disconnected(let reason, let code):
            print("[SignalTransport] WebSocket disconnected: \(reason) with code: \(code)")
            isConnected = false

        case .error(let error):
            print("[SignalTransport] WebSocket error: \(error?.localizedDescription ?? "Unknown error")")

        default:
            break
        }
    }
}
