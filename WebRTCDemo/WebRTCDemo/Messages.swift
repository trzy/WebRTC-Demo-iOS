//
//  Messages.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//

import Foundation

protocol JSONEncodable: Encodable {
    func toJSON() -> String
}

extension JSONEncodable {
    func toJSON() -> String {
        let json = try! JSONEncoder().encode(self)
        return String(data: json, encoding: .utf8)!
    }
}

struct HelloMessage: Codable, JSONEncodable {
    var type: String { return "HelloMessage" }
    let message: String

    enum CodingKeys: String, CodingKey {
        case type, message
    }

    init(message: String) {
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(message, forKey: .message)
    }
}

struct RoleMessage: Codable, JSONEncodable {
    var type: String { return "RoleMessage" }
    let role: String

    enum CodingKeys: String, CodingKey {
        case type, role
    }

    init(role: String) {
        self.role = role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(String.self, forKey: .role)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(role, forKey: .role)
    }
}

struct PeerConnectedMessage: Codable, JSONEncodable {
    var type: String { return "PeerConnectedMessage" }

    enum CodingKeys: String, CodingKey {
        case type
    }

    init() {
    }

    init(from decoder: Decoder) throws {
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
    }
}

struct OfferMessage: Codable, JSONEncodable {
    var type: String { return "OfferMessage" }
    let data: String

    enum CodingKeys: String, CodingKey {
        case type, data
    }

    init(data: String) {
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(String.self, forKey: .data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(data, forKey: .data)
    }
}

struct AnswerMessage: Codable, JSONEncodable {
    var type: String { return "AnswerMessage" }
    let data: String

    enum CodingKeys: String, CodingKey {
        case type, data
    }

    init(data: String) {
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(String.self, forKey: .data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(data, forKey: .data)
    }
}

enum Message: Decodable {
    case hello(HelloMessage)
    case role(RoleMessage)
    case peerConnected(PeerConnectedMessage)
    case offer(OfferMessage)
    case answer(AnswerMessage)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum ObjectType: String, Codable {
        case hello = "HelloMessage"
        case role = "RoleMessage"
        case peerConnected = "PeerConnectedMessage"
        case offer = "OfferMessage"
        case answer = "AnswerMessage"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ObjectType.self, forKey: .type)
        switch type {
        case .hello:
            let msg = try HelloMessage(from: decoder)
            self = .hello(msg)
        case .role:
            let msg = try RoleMessage(from: decoder)
            self = .role(msg)
        case .peerConnected:
            let msg = try PeerConnectedMessage(from: decoder)
            self = .peerConnected(msg)
        case .offer:
            let msg = try OfferMessage(from: decoder)
            self = .offer(msg)
        case .answer:
            let msg = try AnswerMessage(from: decoder)
            self = .answer(msg)
        }
    }

    static func decode(from json: String) -> Message? {
        guard let jsonData = json.data(using: .utf8) else { return nil }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Message.self, from: jsonData)
        } catch {
            print("[Message] Error: Unable to decode JSON: \(error.localizedDescription)")
        }
        return nil
    }
}
