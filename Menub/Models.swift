//
//  Models.swift
//  Menub
//
//  위성 앱이 공유 폴더에 기록하는 매니페스트 모델. (개발지침 §7)
//  뷰 비의존 코어 타입.
//

import Foundation

/// 위성 앱이 `~/Library/Application Support/menub/manifests/<id>.json`에 기록하는 자기 정보.
struct SatelliteManifest: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let urlScheme: String
    /// 실행 중 여부를 감지하기 위한 앱 번들 식별자(선택). 없으면 실행 상태를 표시하지 않는다.
    var bundleIdentifier: String? = nil
    var iconRef: String?
    var actions: [SatelliteAction]

    /// `iconRef`가 `"sf:<name>"` 형식이면 그 SF Symbol 이름을, 아니면 기본 심볼을 돌려준다.
    var systemImageName: String {
        Self.systemImageName(from: iconRef)
    }

    static func systemImageName(from iconRef: String?) -> String {
        guard let iconRef, iconRef.hasPrefix("sf:") else { return "app.dashed" }
        let name = String(iconRef.dropFirst(3))
        return name.isEmpty ? "app.dashed" : name
    }
}

/// 위성이 노출하는 개별 액션. URL로 호출된다. (실호출은 M3)
struct SatelliteAction: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let invoke: String
    var keywords: [String]?
    var iconRef: String?

    var systemImageName: String {
        SatelliteManifest.systemImageName(from: iconRef)
    }
}
