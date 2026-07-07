//
//  HotkeyManager.swift
//  Menub
//
//  전역 단축키 등록. Carbon RegisterEventHotKey를 사용한다 — 앱이 비활성이어도 동작하고,
//  접근성/입력 모니터링 권한이 필요 없다. (개발지침 §8-1, §11)
//  눌리면 onTrigger를 호출한다. 뷰에 의존하지 않는다.
//

import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    /// 단축키가 눌렸을 때 호출된다. (팔레트 토글을 연결)
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    // 'mnbu' 시그니처로 이 앱의 핫키를 식별.
    private let hotKeyID = EventHotKeyID(signature: 0x6D6E6275, id: 1)

    /// 단축키를 등록한다. keyCode는 가상 키코드, modifiers는 Carbon 수식키 마스크.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregister()
        installHandlerIfNeeded()
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // 캡처 없는 C 함수 포인터. userData로 자신을 되찾는다.
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return noErr }
            var pressedID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressedID
            )
            guard err == noErr else { return noErr }
            // 핫키 이벤트는 메인 런루프에서 디스패치되므로 메인 액터 격리를 단언한다.
            MainActor.assumeIsolated {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onTrigger?()
            }
            return noErr
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }
}
