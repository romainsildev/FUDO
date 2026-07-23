//
//  FUDOWidgetBundle.swift
//  FUDOWidget
//
//  The widget extension's entry point. Small + medium home-screen widgets only —
//  no Live Activity, no Control widget (the Xcode template stubs are removed).
//

import WidgetKit
import SwiftUI

@main
struct FUDOWidgetBundle: WidgetBundle {
    var body: some Widget {
        FUDOWidget()
    }
}
