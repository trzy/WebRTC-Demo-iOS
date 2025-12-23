//
//  Server.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//
//  Signalling server.
//

import Foundation
import Starscream

class Server {
    private var _server: WebSocketServer
    private var _ws: WebSocket!

    init() {
        let address = "ws://localhost"
        let port: UInt16 = 8080
        _server = WebSocketServer()
        if let error = _server.start(address: address, port: port) {
            print("[Server] Error: Unable to start server: \(error.localizedDescription)")
        } else {
            print("[Server] Server started on \(address):\(port)")
        }
        _server.onEvent = onEvent

        // Test: connect to self
        let url = URL(string: "ws://localhost:\(port)")!
        _ws = WebSocket(request: URLRequest(url: url))
        _ws.connect()
    }

    private func onEvent(event: ServerEvent) {
        print("[Server] Event: \(event)")
    }
}
