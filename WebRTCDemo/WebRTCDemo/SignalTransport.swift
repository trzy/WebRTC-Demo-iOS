//
//  SignalTransport.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//

import Foundation
import Starscream

class SignalTransport {
    private let _ws: WebSocket

    init() {
        let url = URL(string: "ws://192.168.0.128:8000/ws")!
        _ws = WebSocket(request: URLRequest(url: url))
        _ws.delegate = self
        _ws.connect()
    }
}

extension SignalTransport: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(_):
            print("[SignalTransport] WebSocket connected")
            let hello = HelloMessage(message: "Hello from iOS!")
            _ws.write(string: hello.toJSON())

        case .text(let string):
            print("[SignalTransport] Received message: \(string)")

            if let messageType = Message.decode(from: string) {
                switch (messageType) {
                case .hello(let message):
                    print("[SignalTransport] Peer said hello: \(message.message)")

                default:
                    print("[SignalTransport] Message not handled: \(messageType)")
                }
            } else {
                print("[SignalTransport] Ignoring unknown message")
            }

        case .disconnected(let reason, let code):
            print("[SignalTransport] WebSocket disconnected: \(reason) with code: \(code)")

        case .error(let error):
            print("[SignalTransport] WebSocket error: \(error?.localizedDescription ?? "Unknown error")")

        default:
            break
        }
    }
}
