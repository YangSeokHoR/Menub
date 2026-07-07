//
//  MenubTests.swift
//  MenubTests
//
//  Created by seokho on 7/7/26.
//

import Testing
import Foundation
@testable import Menub

@MainActor
struct MenubTests {

    @Test func invokerOpensValidURL() throws {
        var openedURL: URL?
        let invoker = Invoker(openURL: { url in
            openedURL = url
            return true
        })
        let action = SatelliteAction(id: "deploy", title: "배포 실행", invoke: "runlet://run/deploy")

        let result = invoker.invoke(action)

        #expect(openedURL == URL(string: "runlet://run/deploy"))
        #expect(result == .opened(URL(string: "runlet://run/deploy")!))
    }

    @Test func invokerReportsFailureWhenOpenFails() throws {
        let invoker = Invoker(openURL: { _ in false })
        let action = SatelliteAction(id: "build", title: "빌드", invoke: "runlet://run/build")

        let result = invoker.invoke(action)

        #expect(result == .failed(URL(string: "runlet://run/build")!))
    }

    @Test func invokerRejectsInvalidURL() throws {
        var openCalled = false
        let invoker = Invoker(openURL: { _ in
            openCalled = true
            return true
        })
        // 빈 문자열은 URL로 만들 수 없다.
        let action = SatelliteAction(id: "bad", title: "잘못됨", invoke: "")

        let result = invoker.invoke(action)

        #expect(result == .invalidURL)
        #expect(openCalled == false)
    }

    // MARK: - ConfigStore / RegistrationCoordinator

    /// 임시 디렉터리를 쓰는 격리된 ConfigStore와 Coordinator를 만든다.
    private func makeIsolatedConfig() -> (ConfigStore, RegistrationCoordinator, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let coordinator = RegistrationCoordinator(managedURL: dir.appendingPathComponent("managed.json"))
        let config = ConfigStore(coordinator: coordinator, configURL: dir.appendingPathComponent("config.json"))
        return (config, coordinator, dir)
    }

    @Test func togglingEnabledPersistsAndSyncsManagedFlag() throws {
        let (config, coordinator, dir) = makeIsolatedConfig()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(config.isEnabled("runlet") == false)
        #expect(coordinator.managedIDs() == [])

        config.setEnabled("runlet", true)

        #expect(config.isEnabled("runlet") == true)
        #expect(config.enabledIDs == ["runlet"])
        // 켜진 위성이 관리 플래그 파일에 반영된다(위성이 아이콘을 숨기는 근거).
        #expect(coordinator.managedIDs() == ["runlet"])

        config.setEnabled("runlet", false)
        #expect(config.isEnabled("runlet") == false)
        #expect(coordinator.managedIDs() == [])
    }

    @Test func enabledStatePersistsAcrossReload() throws {
        let (config, coordinator, dir) = makeIsolatedConfig()
        defer { try? FileManager.default.removeItem(at: dir) }

        config.setEnabled("clip", true)

        // 같은 경로로 새 스토어를 만들어 디스크에서 다시 읽는다.
        let reloaded = ConfigStore(
            coordinator: coordinator,
            configURL: dir.appendingPathComponent("config.json")
        )
        #expect(reloaded.isEnabled("clip") == true)
    }

    @Test func runletPinnedByDefault() throws {
        let (config, _, dir) = makeIsolatedConfig()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(config.isPinned("runlet") == true)
        #expect(config.isPinned("clip") == false)
    }

    // MARK: - PaletteSearch

    private var sampleItems: [PaletteItem] {
        let runlet = SatelliteManifest(
            id: "runlet", displayName: "Runlet", urlScheme: "runlet", iconRef: "sf:terminal",
            actions: [
                SatelliteAction(id: "deploy", title: "배포 실행", invoke: "runlet://run/deploy", keywords: ["deploy"]),
                SatelliteAction(id: "build", title: "빌드", invoke: "runlet://run/build")
            ]
        )
        let clip = SatelliteManifest(
            id: "clip", displayName: "Clip", urlScheme: "clip", iconRef: "sf:doc",
            actions: [SatelliteAction(id: "history", title: "기록 열기", invoke: "clip://open/history")]
        )
        return PaletteSearch.items(
            manifests: [clip, runlet],
            isEnabled: { _ in true },
            isPinned: { $0 == "runlet" }
        )
    }

    @Test func flattenPutsPinnedSatelliteFirst() throws {
        // Runlet이 핀이므로 clip보다 먼저 나온다.
        #expect(sampleItems.first?.satelliteId == "runlet")
        #expect(sampleItems.count == 3)
    }

    @Test func actionQueryAutoselectsMatch() throws {
        let result = PaletteSearch.run(items: sampleItems, query: "배포")
        #expect(result.autoselect == 0)
        #expect(result.items.first?.action.id == "deploy")
    }

    @Test func appAndActionTokensNarrowToAction() throws {
        // "runlet 배포": runlet은 앱 이름, 배포는 액션 제목 → 액션 수준 자동 선택.
        let result = PaletteSearch.run(items: sampleItems, query: "runlet 배포")
        #expect(result.autoselect == 0)
        #expect(result.items.first?.action.id == "deploy")
    }

    @Test func appNameOnlyRevealsActionsWithoutAutoselect() throws {
        // 앱 이름만: 그 앱 액션이 다 보이되 자동 선택은 없음(Enter는 흔들림).
        let result = PaletteSearch.run(items: sampleItems, query: "runlet")
        #expect(result.autoselect == nil)
        #expect(result.items.count == 2)
        #expect(result.items.allSatisfy { $0.satelliteId == "runlet" })
    }

    @Test func appNamePlusWrongTextMatchesNothing() throws {
        // 앱 이름 + 정의되지 않은 텍스트 → 결과 없음(Enter는 흔들림).
        let result = PaletteSearch.run(items: sampleItems, query: "runlet 아무거나")
        #expect(result.items.isEmpty)
        #expect(result.autoselect == nil)
    }

    @Test func emptyQueryShowsAllForBrowsing() throws {
        let result = PaletteSearch.run(items: sampleItems, query: "")
        #expect(result.items.count == 3)
        #expect(result.autoselect == nil)
    }
}
