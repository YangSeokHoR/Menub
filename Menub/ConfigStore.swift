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
    var paletteHotkey: String?  // M5에서 사용
}

@Observable
final class ConfigStore {
    private(set) var config: HubConfig

    @ObservationIgnored let configURL: URL
    @ObservationIgnored private let coordinator: RegistrationCoordinator

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

    /// 현재 허브에 포함(enabled)된 위성 id 목록.
    var enabledIDs: [String] {
        config.entries.filter(\.enabled).map(\.satelliteId)
    }

    private func entry(for satelliteId: String) -> HubConfigEntry? {
        config.entries.first { $0.satelliteId == satelliteId }
    }

    // MARK: - 변경

    /// 위성의 허브 포함 여부를 켜고 끈다. 저장 후 관리 플래그를 동기화한다.
    func setEnabled(_ satelliteId: String, _ enabled: Bool) {
        if let index = config.entries.firstIndex(where: { $0.satelliteId == satelliteId }) {
            config.entries[index].enabled = enabled
        } else {
            config.entries.append(
                HubConfigEntry(
                    satelliteId: satelliteId,
                    enabled: enabled,
                    pinned: satelliteId == Self.defaultPinnedID,
                    sortIndex: config.entries.count
                )
            )
        }
        save()
        syncManaged()
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
