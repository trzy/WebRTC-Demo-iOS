//
//  ContentView.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var _viewModel = ChatViewModel()

    @State private var _isConnected = false

    init(viewModel: ChatViewModel) {
        __viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ChatView(viewModel: _viewModel, isEnabled: $_isConnected)
        .padding()
        Button("Test") {
            _isConnected.toggle()
        }
    }
}

#Preview {
    ContentView(viewModel: ChatViewModel())
}
