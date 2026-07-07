//
//  PaletteController.swift
//  Menub
//
//  팔레트를 담는 borderless NSPanel의 표시/숨김을 관리한다. SwiftUI PaletteView를 호스팅.
//  MenuBarExtra 팝오버와 독립된 별도 패널이라 서로를 닫지 않는다. (개발지침 §6, §8-6)
//

import AppKit
import SwiftUI

@MainActor
final class PaletteController {
    private let registry: RegistryStore
    private let config: ConfigStore
    private let invoker: Invoker
    private var panel: NSPanel?

    init(registry: RegistryStore, config: ConfigStore, invoker: Invoker) {
        self.registry = registry
        self.config = config
        self.invoker = invoker
    }

    /// 떠 있으면 닫고, 아니면 화면 중앙에 열어 검색 필드에 포커스한다.
    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        registry.load()
        let panel = panel ?? makePanel()
        self.panel = panel
        centerOnActiveScreen(panel)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let root = PaletteView(
            registry: registry,
            config: config,
            invoker: invoker,
            onClose: { [weak self] in self?.hide() }
        )
        panel.contentView = NSHostingView(rootView: root)
        return panel
    }

    private func centerOnActiveScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY + frame.height * 0.12 - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

/// borderless 패널은 기본적으로 key가 될 수 없어 타이핑을 못 받는다. key/main이 되도록 허용.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
