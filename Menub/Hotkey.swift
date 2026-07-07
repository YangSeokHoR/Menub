//
//  Hotkey.swift
//  Menub
//
//  팔레트 전역 단축키 표현. 가상 키코드 + Carbon 수식키 마스크로 저장하고,
//  NSEvent(레코더 입력)에서 만들거나 표시 문자열로 렌더링한다. (개발지침 §9 M6)
//

import AppKit
import Carbon.HIToolbox

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon 수식키 마스크 (cmdKey 등)
    var display: String

    static let `default` = Hotkey(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey | cmdKey),
        display: "⌥⌘Space"
    )

    /// 레코더가 잡은 키 이벤트로 단축키를 만든다. 수식키가 하나도 없으면 nil(전역 단축키로 부적절).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        guard carbon != 0 else { return nil }

        self.keyCode = UInt32(event.keyCode)
        self.modifiers = carbon
        self.display = Hotkey.displayString(
            keyCode: event.keyCode,
            flags: flags,
            characters: event.charactersIgnoringModifiers
        )
    }

    init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }

    private static func displayString(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String?) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option)  { result += "⌥" }
        if flags.contains(.shift)   { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += keyName(keyCode: keyCode, characters: characters)
        return result
    }

    private static func keyName(keyCode: UInt16, characters: String?) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        default:
            if let characters, !characters.isEmpty {
                return characters.uppercased()
            }
            return "Key\(keyCode)"
        }
    }
}
