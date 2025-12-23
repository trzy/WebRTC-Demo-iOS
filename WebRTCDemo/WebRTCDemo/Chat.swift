//
//  Chat.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//

import Combine
import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isSent: Bool
}

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []

    // Callback for when user sends a message
    var onMessageSent: ((String) -> Void)?

    // Call this to inject received messages
    func receiveMessage(_ text: String) {
        let message = ChatMessage(text: text, isSent: false)
        messages.append(message)
    }

    // Call this when user sends a message
    func sendMessage(_ text: String) {
        let message = ChatMessage(text: text, isSent: true)
        messages.append(message)
        onMessageSent?(text)
    }
}

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""

    @Binding var isEnabled: Bool

    init(viewModel: ChatViewModel, isEnabled: Binding<Bool>) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._isEnabled = isEnabled
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            HStack {
                                if message.isSent {
                                    Spacer()
                                }

                                Text(message.text)
                                    .padding(10)
                                    .background(message.isSent ? Color.blue : Color.gray.opacity(0.3))
                                    .foregroundColor(message.isSent ? .white : .primary)
                                    .cornerRadius(12)

                                if !message.isSent {
                                    Spacer()
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(!isEnabled)

                Button("Send") {
                    sendMessage()
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || !isEnabled)
            }
            .padding()
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        viewModel.sendMessage(text)
        messageText = ""
    }
}
