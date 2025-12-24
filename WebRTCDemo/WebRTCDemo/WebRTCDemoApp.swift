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
    private let _client = WebRTCClient()
    private let _viewModel = ChatViewModel()
    private var _subscriptions = Set<AnyCancellable>()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: _viewModel, isConnected: .constant(true))    //TODO: properly wire connection state somehow
        }
    }

    init() {
        _transport.$message.sink { [weak _client] (message: Message?) in
            guard let client = _client,
                  let message = message else {
                return
            }

            switch (message) {
            case .role(let message):
                client.setRole(message.role == "initiator" ? .initiator : .responder)

            case .peerConnected(_):
                client.onPeerAvailable()

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
}
