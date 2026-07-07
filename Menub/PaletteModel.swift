//
//  PaletteModel.swift
//  Menub
//
//  팔레트 검색의 순수 로직. 자유 텍스트를 URL로 해석하지 않고, 정의된 액션 집합에서
//  필터링만 한다. 실행은 항상 "선택된 정의 액션"에 대해서만 일어난다. (개발지침 §5, §9 M5)
//

import Foundation

/// 위성 하나의 액션 하나를 평탄화한 팔레트 항목.
struct PaletteItem: Identifiable, Hashable {
    let satelliteId: String
    let satelliteName: String
    let action: SatelliteAction

    var id: String { "\(satelliteId)/\(action.id)" }
    var title: String { action.title }
    var systemImageName: String { action.systemImageName }
}

enum PaletteSearch {
    /// 검색 결과와 자동 선택 인덱스. autoselect가 nil이면 Enter는 실행 없이 흔들림 신호만 준다.
    struct Result: Equatable {
        var items: [PaletteItem]
        var autoselect: Int?
    }

    /// 가용 ∩ enabled 위성의 액션을 평탄화한다. 핀 위성이 앞, 그다음 이름순.
    static func items(
        manifests: [SatelliteManifest],
        isEnabled: (String) -> Bool,
        isPinned: (String) -> Bool
    ) -> [PaletteItem] {
        manifests
            .filter { isEnabled($0.id) }
            .sorted { lhs, rhs in
                let lp = isPinned(lhs.id), rp = isPinned(rhs.id)
                if lp != rp { return lp }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .flatMap { manifest in
                manifest.actions.map {
                    PaletteItem(satelliteId: manifest.id, satelliteName: manifest.displayName, action: $0)
                }
            }
    }

    /// 쿼리로 항목을 필터링한다.
    /// - 모든 토큰이 (액션 제목 ∪ 키워드 ∪ 앱 이름)에 들어와야 결과에 포함된다.
    /// - 토큰 중 하나라도 액션 제목/키워드에 걸리면 "액션 수준" 매칭 → 자동 선택 대상.
    /// - 앱 이름에만 걸리거나(앱 열람) 빈 쿼리면 자동 선택하지 않는다(안전: 명시 선택 필요).
    static func run(items: [PaletteItem], query: String) -> Result {
        let tokens = normalize(query).split(separator: " ").map(String.init)

        let matched = items.filter { item in
            let text = combinedText(item)
            return tokens.allSatisfy { text.contains($0) }
        }

        guard !tokens.isEmpty else {
            return Result(items: matched, autoselect: nil)
        }

        let actionLevel = matched.filter { item in
            let text = actionText(item)
            return tokens.contains { text.contains($0) }
        }
        let appOnly = matched.filter { item in
            let text = actionText(item)
            return !tokens.contains { text.contains($0) }
        }

        return Result(
            items: actionLevel + appOnly,
            autoselect: actionLevel.isEmpty ? nil : 0
        )
    }

    static func normalize(_ string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func actionText(_ item: PaletteItem) -> String {
        let keywords = item.action.keywords?.joined(separator: " ") ?? ""
        return normalize(item.action.title + " " + keywords)
    }

    private static func combinedText(_ item: PaletteItem) -> String {
        actionText(item) + " " + normalize(item.satelliteName)
    }
}
