//
//  MenubApp.swift
//  Menub
//
//  Created by seokho on 7/7/26.
//

import SwiftUI

@main
struct MenubApp: App {
    // 앱이 소유하는 가용 도구 진실원천. @Observable이므로 @State로 보유한다.
    @State private var registry = RegistryStore()

    var body: some Scene {
        // 단일 상태 아이템 소유. .window 스타일로 클릭 시 팝오버형 패널을 띄운다. (macOS 13+)
        MenuBarExtra("menub", systemImage: "square.grid.2x2") {
            PopoverRootView(registry: registry)
        }
        .menuBarExtraStyle(.window)
    }
}
