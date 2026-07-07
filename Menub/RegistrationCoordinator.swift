//
//  RegistrationCoordinator.swift
//  Menub
//
//  허브가 관리 중인 위성 id 집합을 공유 규약 파일에 기록한다. (개발지침 §6, §7)
//  위성 앱은 실행 시 이 파일을 읽어 자기 id가 있으면 NSStatusItem을 만들지 않는다. (§8-2)
//  뷰에 의존하지 않는다.
//

import Foundation

/// 위성 앱이 읽는 공유 규약 파일 스키마. (managed.json)
struct ManagedRegistry: Codable, Equatable {
    var managedIDs: [String]
}

struct RegistrationCoordinator {
    /// `~/Library/Application Support/menub/managed.json`
    let managedURL: URL

    init(managedURL: URL? = nil) {
        self.managedURL = managedURL ?? Self.defaultManagedURL()
    }

    static func defaultManagedURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("menub/managed.json", isDirectory: false)
    }

    /// 허브가 관리(=아이콘 숨김) 중인 위성 id 목록을 통째로 기록한다.
    func setManaged(ids: [String]) {
        let registry = ManagedRegistry(managedIDs: ids.sorted())
        guard let data = try? JSONEncoder().encode(registry) else { return }
        try? FileManager.default.createDirectory(
            at: managedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: managedURL, options: .atomic)
    }

    /// 현재 관리 중으로 기록된 위성 id 목록. (위성 쪽 로직과 동일한 읽기)
    func managedIDs() -> [String] {
        guard let data = try? Data(contentsOf: managedURL),
              let registry = try? JSONDecoder().decode(ManagedRegistry.self, from: data) else {
            return []
        }
        return registry.managedIDs
    }
}
