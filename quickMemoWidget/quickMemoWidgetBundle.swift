//
//  quickMemoWidgetBundle.swift
//  quickMemoWidget
//
//  Created by kiichi yokokawa on 2025/09/13.
//

import WidgetKit
import SwiftUI

// Note: @main is defined in QuickMemoWidget.swift
// This file is kept for future expansion with multiple widgets
struct quickMemoWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickMemoWidget()
        // Future widgets can be added here
        // quickMemoWidgetControl()
        // quickMemoWidgetLiveActivity()
    }
}
