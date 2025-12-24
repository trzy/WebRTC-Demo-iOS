//
//  ContentView.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ChatViewModel()
    @Binding var isConnected: Bool

    var body: some View {
        ChatView(viewModel: viewModel, isEnabled: $isConnected)
        .padding()
    }
}

#Preview {
    ContentView(viewModel: ChatViewModel(), isConnected: .constant(true))
}
