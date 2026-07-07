//
//  MenubModels.swift
//  MenubKit
//
//  menub 허브와 위성이 공유하는 계약 스키마. 허브의 SatelliteManifest/ManagedRegistry와
//  필드가 일치해야 하며, 이 패키지가 그 단일 진실원천이다.
//

import Foundation

/// 위성이 노출하는 액션 하나. `invoke`는 MenubSatellite가 파생하므로 직접 만들지 말 것.
public struct MenubAction: Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var invoke: String
    public var keywords: [String]?
    public var iconRef: String?

    public init(id: String, title: String, invoke: String, keywords: [String]? = nil, iconRef: String? = nil) {
        self.id = id
        self.title = title
        self.invoke = invoke
        self.keywords = keywords
        self.iconRef = iconRef
    }
}

/// 위성이 `manifests/<id>.json`에 기록하는 자기 정보. (계약 1)
public struct MenubManifest: Codable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public var urlScheme: String
    public var bundleIdentifier: String?
    public var iconRef: String?
    public var actions: [MenubAction]

    public init(
        id: String,
        displayName: String,
        urlScheme: String,
        bundleIdentifier: String? = nil,
        iconRef: String? = nil,
        actions: [MenubAction] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.bundleIdentifier = bundleIdentifier
        self.iconRef = iconRef
        self.actions = actions
    }
}

/// 허브가 관리(=아이콘 숨김) 중인 위성 id 목록. 위성이 읽는 `managed.json`. (계약 3)
public struct MenubManagedRegistry: Codable, Hashable, Sendable {
    public var managedIDs: [String]

    public init(managedIDs: [String] = []) {
        self.managedIDs = managedIDs
    }
}
