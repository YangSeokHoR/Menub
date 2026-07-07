//
//  RuntimeMonitor.swift
//  Menub
//
//  위성 앱의 실행 중 여부를 추적한다. NSWorkspace의 실행/종료 알림을 관찰해 갱신한다.
//  (개발지침 §7 SatelliteRuntimeState.isRunning, §9 M6) 뷰에 의존하지 않는다.
//

import AppKit
import Observation

@Observable
final class RuntimeMonitor {
    private(set) var runningBundleIDs: Set<String> = []

    init() {
        refresh()
        observe()
    }

    func isRunning(_ bundleIdentifier: String?) -> Bool {
        Self.contains(bundleIdentifier, in: runningBundleIDs)
    }

    /// 순수 판정(테스트용).
    static func contains(_ bundleIdentifier: String?, in set: Set<String>) -> Bool {
        guard let bundleIdentifier else { return false }
        return set.contains(bundleIdentifier)
    }

    private func refresh() {
        runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
    }

    private func observe() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }
}
