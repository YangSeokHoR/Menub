//
//  MenubApp.swift
//  Menub
//
//  Created by seokho on 7/7/26.
//

import SwiftUI

@main
struct MenubApp: App {
    // 코어 스토어와 팔레트/단축키는 AppDelegate가 소유한다(팔레트 NSPanel 수명 관리 때문).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 단일 상태 아이템 소유. .window 스타일로 클릭 시 팝오버형 패널을 띄운다. (macOS 13+)
        MenuBarExtra("menub", systemImage: "square.grid.2x2") {
            PopoverRootView(
                registry: appDelegate.registry,
                config: appDelegate.config,
                invoker: appDelegate.invoker
            )
        }
        .menuBarExtraStyle(.window)

        // 위성 토글 설정 창.
        Settings {
            SettingsView(registry: appDelegate.registry, config: appDelegate.config)
        }
    }
}
