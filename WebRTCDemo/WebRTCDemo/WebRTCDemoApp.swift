//
//  WebRTCDemoApp.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//

import Combine
import SwiftUI
import WebRTC

@main
struct WebRTCDemoApp: App {
    private let _transport = SignalTransport()
    //private let _client = WebRTCClient(receiveMedia: false, cameraPosition: .front)
    private let _viewModel = ChatViewModel()
    private var _subscriptions = Set<AnyCancellable>()

    @StateObject private var _asyncWebRtcClient = AsyncWebRtcClient()
    @State private var _isConnected: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: _viewModel, isConnected: $_isConnected)   //TODO: properly wire connection state somehow
                .environmentObject(_asyncWebRtcClient)
                .task {
                    // Run WebRTC on connection to signaling server
                    for await isConnected in _transport.$isConnected.values {
                        if isConnected {
                            print("Connected")
                            await _asyncWebRtcClient.run()
                        }
                    }
                }
                .task {
                    // Disconnect
                    for await isConnected in _transport.$isConnected.values {
                        if !isConnected {
                            print("Disconnected")
                            await _asyncWebRtcClient.stop()
                        }
                    }
                }
                .task {
                    // When WebRTC is locally ready to establish a connection, let the signaling
                    // server know
                    for await _ in _asyncWebRtcClient.readyToConnectEvent {
                        _transport.send(ReadyToConnectMessage().toJSON())
                    }
                }
                .task {
                    for await sdp in _asyncWebRtcClient.offerToSend {
                        _transport.send(OfferMessage(data: sdp).toJSON())
                    }
                }
                .task {
                    for await sdp in _asyncWebRtcClient.answerToSend {
                        _transport.send(AnswerMessage(data: sdp).toJSON())
                    }
                }
                .task {
                    for await candidate in _asyncWebRtcClient.iceCandidateToSend {
                        _transport.send(ICECandidateMessage(data: candidate).toJSON())
                    }
                }
                .task {
                    for await textData in _asyncWebRtcClient.textDataReceived {
                        _viewModel.receiveMessage(textData)
                    }
                }
                .task {
                    for await isConnected in _asyncWebRtcClient.isConnected {
                        _isConnected = isConnected
                    }
                }
                .task {
                    for await message in _transport.$message.values {
                        switch (message) {
                        case .role(let message):
                            await _asyncWebRtcClient.onRoleAssigned(message.role == "initiator" ? .initiator : .responder)

                        case .iceCandidate(let message):
                            await _asyncWebRtcClient.onIceCandidateReceived(jsonString: message.data)

                        case .offer(let message):
                            await _asyncWebRtcClient.onOfferReceived(jsonString: message.data)

                        case .answer(let message):
                            await _asyncWebRtcClient.onAnswerReceived(jsonString: message.data)

                        default:
                            //TODO: not yet implemented
                            break;
                        }
                    }
                }
        }
    }
/*
    init() {
        _transport.$isConnected.sink { [weak _client] (isConnected: Bool) in
            guard let client = _client else { return }
            if isConnected {
                // For this simple demo, this will only really work the first time
                client.start()
            }
        }.store(in: &_subscriptions)

        _transport.$message.sink { [weak _client] (message: Message?) in
            guard let client = _client,
                  let message = message else {
                return
            }

            switch (message) {
            case .role(let message):
                client.onRoleReceived(message.role == "initiator" ? .initiator : .responder)

            case .iceCandidate(let message):
                client.onICECandidateReceived(jsonString: message.data)

            case .offer(let message):
                client.onOfferReceived(jsonString: message.data)

            case .answer(let message):
                client.onAnswerReceived(jsonString: message.data)

            default:
                //TODO: not yet implemented
                break;
            }

        }.store(in: &_subscriptions)

        _client.$readyToConnect.sink { [weak _transport] (ready: Bool) in
            guard let transport = _transport else { return }
            if ready {
                transport.send(ReadyToConnectMessage().toJSON())
            }
        }.store(in: &_subscriptions)

        _client.$offer.sink { [weak _transport] (offer: String?) in
            guard let transport = _transport,
                  let offer = offer else {
                return
            }
            transport.send(OfferMessage(data: offer).toJSON())
        }.store(in: &_subscriptions)

        _client.$iceCandidate.sink { [weak _transport] (candidate: String?) in
            guard let transport = _transport,
                  let candidate = candidate else {
                return
            }
            transport.send(ICECandidateMessage(data: candidate).toJSON())
        }.store(in: &_subscriptions)

        _client.$answer.sink { [weak _transport] (answer: String?) in
            guard let transport = _transport,
                  let answer = answer else {
                return
            }
            transport.send(AnswerMessage(data: answer).toJSON())
        }.store(in: &_subscriptions)

        _client.$textData.sink { [weak _viewModel] (textData: String?) in
            guard let viewModel = _viewModel,
                  let chatMessage = textData else {
                return
            }
            viewModel.receiveMessage(chatMessage)
        }.store(in: &_subscriptions)

        _viewModel.$outboundMessage.sink { [weak _client] (message: String?) in
            guard let client = _client,
                  let message else {
                return
            }
            client.sendTextData(message)
        }.store(in: &_subscriptions)
    }
 */
}
