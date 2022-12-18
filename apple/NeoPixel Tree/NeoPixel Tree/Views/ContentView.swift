//
//  ContentView.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @State private var color = Color(.sRGB, red: 0, green: 0, blue: 0)
    private let vm = ContentViewModel()

    var body: some View {
        Group {
            ColorPicker("Tree Color", selection: $color, supportsOpacity: false)
                .padding()
                .onChange(of: color) { value in
                    vm.colorChange(newColor: value.toPixelColor())
                }
        }.onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                vm.udpClient.restart()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
