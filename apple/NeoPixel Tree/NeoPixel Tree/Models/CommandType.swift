//
//  CommandType.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 11/30/24.
//


enum CommandType {
    // a global command that effects all commands, e.g. brightness
    case global
    // a standard routine that is selectable
    case normal
    // a special system command that shouldn't be selectable or visible, e.g. readback
    case system
}
