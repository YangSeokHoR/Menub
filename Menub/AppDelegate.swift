//
//  AppDelegate.swift
//  Menub
//
//  코어 스토어와 팔레트/단축키를 소유하고, 실행 시 전역 단축키를 등록해 팔레트에 연결한다.
//  (팔레트는 별도 NSPanel이라 AppKit 수명 관리가 필요해 앱델리게이트에서 조립한다.)
//

import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let registry = RegistryStore()
    let config = ConfigStore()
    let invoker = Invoker()

    private lazy var palette = PaletteController(registry: registry, config: config, invoker: invoker)
    private let hotkey = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkey.onTrigger = { [weak self] in self?.palette.toggle() }
        // 기본 단축키: ⌥⌘Space (Spotlight ⌘Space 등과의 충돌 회피)
        let registered = hotkey.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey | cmdKey)
        )
        if !registered {
            NSLog("menub: 전역 단축키 등록 실패(다른 앱이 선점했을 수 있음)")
        }
    }
}
