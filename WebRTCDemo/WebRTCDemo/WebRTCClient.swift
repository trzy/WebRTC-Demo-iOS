//
//  WebRTCClient.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/22/25.
//
//  Resources:
//      - https://medium.com/@ivanfomenko/webrtc-in-swift-in-simple-words-about-the-complex-d9bfe37d4126
//      - https://github.com/stasel/WebRTC-iOS/blob/main/WebRTC-Demo-App/Sources/Services/WebRTCClient.swift
//

import Combine
import WebRTC

// Bundle offer SDP like this (on JavaScript side, this is the expected format)
struct Offer: nonisolated Codable {
    var type = "offer"
    var sdp: String

    static func decode(jsonString: String) -> Offer? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        do {
            let offer = try decoder.decode(Offer.self, from: jsonData)
            return offer
        } catch {
            print("[WebRTCClient] Error decoding offer: \(error.localizedDescription)")
        }
        return nil
    }
}

// Bundle answer SDP like this
struct Answer: nonisolated Codable {
    var type = "answer"
    var sdp: String

    static func decode(jsonString: String) -> Answer? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        do {
            let offer = try decoder.decode(Answer.self, from: jsonData)
            return offer
        } catch {
            print("[WebRTCClient] Error decoding answer: \(error.localizedDescription)")
        }
        return nil
    }
}

// Bundle ICE candidate like this
struct ICECandidate: nonisolated Codable {
    let candidate: String
    let sdpMLineIndex: Int32
    let sdpMid: String?

    static func decode(jsonString: String) -> ICECandidate? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        do {
            let offer = try decoder.decode(ICECandidate.self, from: jsonData)
            return offer
        } catch {
            print("[WebRTCClient] Error decoding ICE candidate: \(error.localizedDescription)")
        }
        return nil
    }
}

class WebRTCClient: NSObject, ObservableObject {
    enum Role {
        case initiator
        case responder
    }

    @Published var isConnected: Bool = false
    @Published var offer: String?
    @Published var iceCandidate: String?
    @Published var answer: String?
    @Published var textData: String?

    private let _factory: RTCPeerConnectionFactory
    private let _peerConnection: RTCPeerConnection
    private var _dataChannel: RTCDataChannel?
    private var _role: Role?
    private var _iceCandidateQueue: [RTCIceCandidate] = []

    private let _mediaConstraints = RTCMediaConstraints(
        mandatoryConstraints: [
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
        ],
        optionalConstraints: nil
    )

    override init() {
        _factory = RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )

        let config = RTCConfiguration()
        config.bundlePolicy = .maxCompat                        // ?
        config.continualGatheringPolicy = .gatherContinually    // ?
        config.rtcpMuxPolicy = .require                         // ?
        config.iceTransportPolicy = .all
        config.tcpCandidatePolicy = .enabled
        config.keyType = .ECDSA
        config.iceServers = [ RTCIceServer(urlStrings: [ "stun:stun.l.google.com:19302" ]) ]

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue    // needed for sharing streams with browsers?
            ],
            optionalConstraints: nil
        )

        // Create peer connection to listen on
        guard let peerConnection = _factory.peerConnection(with: config, constraints: constraints, delegate: nil) else {
            fatalError("Unable to create peer connection")
        }
        _peerConnection = peerConnection

        super.init()

        _dataChannel = _peerConnection.dataChannel(forLabel: "chat", configuration: RTCDataChannelConfiguration())
        _dataChannel?.delegate = self

        peerConnection.delegate = self
    }

    /// Sets role, which will govern which side will kick off the connection process by producing
    /// an offer once the other side is present. This is assigned by our signaling server.
    func setRole(_ role: Role) {
        _role = role
    }

    /// Indicates that a remote peer has connected to the signal server and has been assigned a
    /// role. The connection process will be initatied by the initiator.
    func onPeerAvailable() {
        guard _role == .initiator else { return }
        createOffer()
    }

    /// Add an ICE candidate from the remote peer.
    func onICECandidateReceived(jsonString: String) {
        guard let iceCandidate = ICECandidate.decode(jsonString: jsonString) else { return }
        let candidate = RTCIceCandidate(sdp: iceCandidate.candidate, sdpMLineIndex: iceCandidate.sdpMLineIndex, sdpMid: iceCandidate.sdpMid)

        guard _peerConnection.remoteDescription != nil else {
            // We have not yet received an offer from the peer, so we can't set ICE candidates yet
            //TODO: this is true in JavaScript, is it true here?
            _iceCandidateQueue.append(candidate)
            return
        }

        addIceCandidate(candidate)
    }

    /// Accept offer from a remote peer.
    func onOfferReceived(jsonString: String) {
        guard let offer = Offer.decode(jsonString: jsonString) else { return }
        let sdp = RTCSessionDescription(type: .offer, sdp: offer.sdp)

        _peerConnection.setRemoteDescription(sdp) { [weak self] error in
            if let error = error {
                print("[WebRTCClient] Error: Unable to set remote description from received offer: \(error.localizedDescription)")
                return
            }

            self?.processEnqueuedIceCandidates() {
                self?.respondToOffer()
            }

        }
    }

    /// Accept answer from remote peer.
    func onAnswerReceived(jsonString: String) {
        guard let answer = Answer.decode(jsonString: jsonString) else { return }
        let sdp = RTCSessionDescription(type: .answer, sdp: answer.sdp)

        _peerConnection.setRemoteDescription(sdp) { [weak self] error in
            if let error = error {
                print("[WebRTCClient] Error: Unable to set remote description from received answer: \(error.localizedDescription)")
                return
            }

            self?.processEnqueuedIceCandidates() {
                print("[WebRTCClient] Answer received, WebRTC should now establish connection")
            }
        }
    }

    /// Send a string on the chat data channel.
    func sendTextData(_ text: String) {
        let buffer = RTCDataBuffer(data: text.data(using: .utf8)!, isBinary: false)
        _dataChannel?.sendData(buffer)
    }

    private func createOffer() {
        _peerConnection.offer(for: _mediaConstraints) { [weak self] (sdp: RTCSessionDescription?, error: Error?) in
            if let error = error {
                print("[WebRTCClient] Error: Unable to create offer: \(error.localizedDescription)")
                return
            }

            guard let sdp = sdp else {
                print("[WebRTCClient] Error: Unable to create offer because none was generated")
                return
            }

            self?._peerConnection.setLocalDescription(sdp) { error in
                if let error = error {
                    print("[WebRTCClient] Error: Failed to set offer as local description: \(error.localizedDescription)")
                    return
                }

                guard let sdpString = self?._peerConnection.localDescription?.sdp else {
                    print("[WebRTCClient] Error: Unable to generate offer string")
                    return
                }

                // Publish offer so signaling layer can pick it up and ship it to peer
                self?.offer = String(data: try! JSONEncoder().encode(Offer(sdp: sdpString)), encoding: .utf8)!
            }
        }
    }

    private func addIceCandidate(_ candidate: RTCIceCandidate) {
        _peerConnection.add(candidate) { error in
            if let error = error {
                print("[WebRTCClient] Error: Unable to add ICE candidate: \(error.localizedDescription)")
            }
        }
    }

    private func processEnqueuedIceCandidates(completionHandler: (() -> Void)? = nil) {
        // Recursively add ICE candidates and call completion handler when all are finished
        guard let candidate = _iceCandidateQueue.first else {
            completionHandler?()
            return
        }

        _iceCandidateQueue.remove(at: 0)

        _peerConnection.add(candidate) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("[WebRTCClient] Error: Unable to add ICE candidate: \(error.localizedDescription)")
                return
            }

            // Recursively process next
            self.processEnqueuedIceCandidates(completionHandler: completionHandler)
        }
    }

    private func respondToOffer() {
        // After receiving an offer, create an answer, set that as our local description, and send answer to remote peer
        _peerConnection.answer(for: _mediaConstraints) { [weak self] (sdp: RTCSessionDescription?, error: Error?) in
            if let error = error {
                print("[WebRTCClient] Error: Unable to create answer: \(error.localizedDescription)")
                return
            }

            guard let sdp = sdp else {
                print("[WebRTCClient] Error: Unable to create answer because none was generated")
                return
            }

            self?._peerConnection.setLocalDescription(sdp) { error in
                if let error = error {
                    print("[WebRTCClient] Error: Failed to set answer as local description: \(error.localizedDescription)")
                    return
                }

                guard let sdpString = self?._peerConnection.localDescription?.sdp else {
                    print("[WebRTCClient] Error: Unable to generate answer string")
                    return
                }

                self?.answer = String(data: try! JSONEncoder().encode(Answer(sdp: sdpString)), encoding: .utf8)!
            }
        }
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let stateToString: [RTCIceConnectionState: String] = [
            .checking: "checking",
            .connected: "connected",
            .disconnected: "disconnected",
            .closed: "closed",
            .completed: "completed",
            .count: "count",
            .failed: "failed",
            .new: "new",
        ]
        let stateName = stateToString[newState] ?? "Unknown (\(newState.rawValue))"
        print("[WebRTClient] Connection state: \(stateName)")

        switch newState {
        case .connected:
            isConnected = true
        case .disconnected:
            isConnected = false
        case .closed, .completed, .failed:
            isConnected = false
        default:
            break
        }

//            switch newState {
//            case .connected:
//                self.connectState.accept(.connected)
//                self.connected()
//            case .disconnected:
//                self.connectState.accept(.disconnected)
//            case .failed:
//                self.failDisconnect()
//            default: break
//            }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let iceCandidate = ICECandidate(candidate: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid)
        let serialized = String(data: try! JSONEncoder().encode(iceCandidate), encoding: .utf8)!

        print("[WebRTCClient] Generated ICE candidate: \(serialized)")

        self.iceCandidate = serialized

//        if readyToSendIceCandidates {
//            self.candidate.onNext(candidate)
//        } else {
//            self.localCandidates.append(candidate)
//        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("[WebRTCClient] Data channel opened: \(dataChannel.description)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove rtpReceiver: RTCRtpReceiver) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
}

extension WebRTCClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("[WebRTCClient] Data channel changed state")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        print("[WebRTCClient] Received data on channel")

        // Publish!
        DispatchQueue.main.async { [weak self] in
            self?.textData = String(data: Data(buffer.data), encoding: .utf8)
        }
    }
}
