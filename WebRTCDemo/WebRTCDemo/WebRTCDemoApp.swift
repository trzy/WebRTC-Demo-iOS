//
//  WebRTCDemoApp.swift
//  WebRTCDemo
//
//  Created by Bart Trzynadlowski on 12/21/25.
//

import SwiftUI

@main
struct WebRTCDemoApp: App {
    private let _signal = SignalTransport()
    private let _viewModel = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: _viewModel)
        }
    }
}
