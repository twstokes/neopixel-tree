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
    @StateObject var vm = ContentViewModel()

    var body: some View {
        Group {
            VStack {
                HStack {
                    ColorPicker("Tree Color", selection: $color, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: color) { value in
                            vm.colorChange(newColor: value.toPixelColor())
                        }

                    Button(action: {
                        vm.rainbowMode()
                    }, label: {
                        Image(systemName: "wand.and.rays")
                            .resizable()
                            .frame(width: 30, height: 30)
                    })

                    Button(action: {
                        vm.sendStillRainbow()
                    }, label: {
                        Image(systemName: "wand.and.stars")
                            .resizable()
                            .frame(width: 30, height: 30)
                    })

                    Button(action: {
                        vm.runningTranscriber.toggle()
                    }, label: {
                        Image(systemName: "mic.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(vm.runningTranscriber ? .red : .gray)
                    })
                }
                Text(vm.text)
                    .font(.system(size: 20))
                    .padding()

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
