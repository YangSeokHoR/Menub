//
//  ConfigStore.swift
//  Menub
//
//  허브 자체 설정의 저장/로드. 위성별 enabled·pinned·sortIndex와 팔레트 단축키. (개발지침 §6, §7)
//  사용자 선택(멤버십)의 진실원천 — 가용성(RegistryStore)과 분리한다.
//  enabled가 바뀌면 RegistrationCoordinator로 관리 플래그(managed.json)를 동기화한다.
//  뷰에 의존하지 않는다.
//

import Foundation
import Observation

/// 허브가 소유하는 위성별 설정.
struct HubConfigEntry: Codable, Hashable {
    var satelliteId: String
    var enabled: Bool
    var pinned: Bool
    var sortIndex: Int
}

/// 허브 전역 설정.
struct HubConfig: Codable {
    var entries: [HubConfigEntry] = []
    var paletteHotkey: Hotkey?
}

@Observable
final class ConfigStore {
    private(set) var config: HubConfig

    @ObservationIgnored let configURL: URL
    @ObservationIgnored private let coordinator: RegistrationCoordinator
    /// 팔레트 단축키가 바뀌면 호출된다(HotkeyManager 재등록 연결용). 뷰/코어 결합을 피해 콜백으로 노출.
    @ObservationIgnored var onPaletteHotkeyChanged: ((Hotkey?) -> Void)?

    // 기본 핀 규칙: Runlet은 최초 등록 시 pinned. (사용자가 이후 변경 가능)
    private static let defaultPinnedID = "runlet"

    init(coordinator: RegistrationCoordinator = RegistrationCoordinator(), configURL: URL? = nil) {
        self.coordinator = coordinator
        self.configURL = configURL ?? Self.defaultConfigURL()
        self.config = Self.load(from: self.configURL)
        syncManaged()
    }

    static func defaultConfigURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("menub/config.json", isDirectory: false)
    }

    // MARK: - 조회

    func isEnabled(_ satelliteId: String) -> Bool {
        entry(for: satelliteId)?.enabled ?? false
    }

    func isPinned(_ satelliteId: String) -> Bool {
        entry(for: satelliteId)?.pinned ?? (satelliteId == Self.defaultPinnedID)
    }

    func sortIndex(_ satelliteId: String) -> Int {
        entry(for: satelliteId)?.sortIndex ?? Int.max
    }

    /// 현재 허브에 포함(enabled)된 위성 id 목록.
    var enabledIDs: [String] {
        config.entries.filter(\.enabled).map(\.satelliteId)
    }

    /// 등록된 단축키(없으면 기본값).
    var effectiveHotkey: Hotkey {
        config.paletteHotkey ?? .default
    }

    /// 핀 우선 → sortIndex → 이름순으로 정렬한다. (팝오버·팔레트·설정 공통 정렬)
    func sorted(_ manifests: [SatelliteManifest]) -> [SatelliteManifest] {
        manifests.sorted { lhs, rhs in
            let lp = isPinned(lhs.id), rp = isPinned(rhs.id)
            if lp != rp { return lp }
            let ls = sortIndex(lhs.id), rs = sortIndex(rhs.id)
            if ls != rs { return ls < rs }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func entry(for satelliteId: String) -> HubConfigEntry? {
        config.entries.first { $0.satelliteId == satelliteId }
    }

    // MARK: - 변경

    /// 위성의 허브 포함 여부를 켜고 끈다. 저장 후 관리 플래그를 동기화한다.
    func setEnabled(_ satelliteId: String, _ enabled: Bool) {
        withEntry(satelliteId) { $0.enabled = enabled }
        save()
        syncManaged()
    }

    /// 위성의 상단 고정 여부를 바꾼다.
    func setPinned(_ satelliteId: String, _ pinned: Bool) {
        withEntry(satelliteId) { $0.pinned = pinned }
        save()
    }

    /// 주어진 순서대로 sortIndex를 다시 매긴다.
    func setOrder(_ orderedIDs: [String]) {
        for (index, id) in orderedIDs.enumerated() {
            withEntry(id) { $0.sortIndex = index }
        }
        save()
    }

    /// 팔레트 단축키를 저장하고 재등록 콜백을 호출한다.
    func setPaletteHotkey(_ hotkey: Hotkey?) {
        config.paletteHotkey = hotkey
        save()
        onPaletteHotkeyChanged?(hotkey)
    }

    /// 항목이 있으면 수정, 없으면 기본값으로 생성 후 수정한다.
    private func withEntry(_ satelliteId: String, _ mutate: (inout HubConfigEntry) -> Void) {
        if let index = config.entries.firstIndex(where: { $0.satelliteId == satelliteId }) {
            mutate(&config.entries[index])
        } else {
            var entry = HubConfigEntry(
                satelliteId: satelliteId,
                enabled: false,
                pinned: satelliteId == Self.defaultPinnedID,
                sortIndex: config.entries.count
            )
            mutate(&entry)
            config.entries.append(entry)
        }
    }

    // MARK: - 영속화

    private static func load(from url: URL) -> HubConfig {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(HubConfig.self, from: data) else {
            return HubConfig()
        }
        return config
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: configURL, options: .atomic)
    }

    /// enabled 위성 목록을 위성 대상 관리 플래그 파일에 반영한다.
    private func syncManaged() {
        coordinator.setManaged(ids: enabledIDs)
    }
}
