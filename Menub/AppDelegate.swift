//
//  AppDelegate.swift
//  Menub
//
//  코어 스토어와 팔레트/단축키/실행 감시를 소유하고, 실행 시 전역 단축키를 등록해 팔레트에 연결한다.
//  (팔레트는 별도 NSPanel이라 AppKit 수명 관리가 필요해 앱델리게이트에서 조립한다.)
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let registry = RegistryStore()
    let config = ConfigStore()
    let runtime = RuntimeMonitor()
    let invoker = Invoker()

    private lazy var palette = PaletteController(registry: registry, config: config, invoker: invoker)
    private let hotkey = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkey.onTrigger = { [weak self] in self?.palette.toggle() }

        // 설정에 저장된 단축키(없으면 기본 ⌥⌘Space)로 등록.
        applyHotkey(config.effectiveHotkey)

        // 사용자가 단축키를 바꾸면 재등록.
        config.onPaletteHotkeyChanged = { [weak self] hotkey in
            self?.applyHotkey(hotkey ?? .default)
        }
    }

    private func applyHotkey(_ hotkey: Hotkey) {
        let registered = self.hotkey.register(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
        if !registered {
            NSLog("menub: 전역 단축키 등록 실패(\(hotkey.display)) — 다른 앱이 선점했을 수 있음")
        }
    }
}
