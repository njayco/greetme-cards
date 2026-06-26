//
//  ContentView.swift
//  GreetMe
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.106, green: 0.078, blue: 0.063).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("GreetMe")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundColor(Color(red: 0.79, green: 0.64, blue: 0.29))
                Text("Send beautiful cards from Messages")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.72, green: 0.66, blue: 0.56))
                Text("Open Messages, tap the app drawer, and choose GreetMe Cards.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.54, green: 0.48, blue: 0.39))
                    .padding(.horizontal, 32)
            }
        }
    }
}

#Preview {
    ContentView()
}
