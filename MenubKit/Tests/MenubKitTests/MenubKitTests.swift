import XCTest
@testable import MenubKit

final class MenubKitTests: XCTestCase {

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return dir
    }

    private func makeSatellite(in dir: URL) -> MenubSatellite {
        MenubSatellite(
            id: "runlet",
            displayName: "Runlet",
            urlScheme: "runlet",
            bundleIdentifier: "com.example.runlet",
            iconRef: "sf:terminal",
            baseDirectory: dir
        )
    }

    func testMakeActionDerivesInvokeURL() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)

        let action = sat.makeAction(id: "deploy", title: "배포 실행", keywords: ["release"])
        XCTAssertEqual(action.invoke, "runlet://action/deploy")
        XCTAssertEqual(action.keywords, ["release"])
    }

    func testWriteManifestRoundTrips() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)
        sat.setActions([
            sat.makeAction(id: "deploy", title: "배포 실행"),
            sat.makeAction(id: "build", title: "빌드")
        ])

        XCTAssertTrue(sat.writeManifest())

        let url = MenubPaths.manifestURL(id: "runlet", in: dir)
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(MenubManifest.self, from: data)

        XCTAssertEqual(decoded.id, "runlet")
        XCTAssertEqual(decoded.displayName, "Runlet")
        XCTAssertEqual(decoded.bundleIdentifier, "com.example.runlet")
        XCTAssertEqual(decoded.actions.map(\.id), ["deploy", "build"])
        XCTAssertEqual(decoded.actions.first?.invoke, "runlet://action/deploy")
    }

    func testRouteParsesActionIDAndCallsHandler() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)

        var invoked: String?
        sat.onInvoke { invoked = $0 }

        XCTAssertTrue(sat.route(URL(string: "runlet://action/deploy")!))
        XCTAssertEqual(invoked, "deploy")
    }

    func testActionIDWithSlashRoundTrips() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)

        let action = sat.makeAction(id: "group/sub", title: "중첩 명령")
        XCTAssertEqual(action.invoke, "runlet://action/group%2Fsub")  // '/'가 인코딩됨

        var invoked: String?
        sat.onInvoke { invoked = $0 }
        XCTAssertTrue(sat.route(URL(string: action.invoke)!))
        XCTAssertEqual(invoked, "group/sub")  // 세그먼트로 안 쪼개지고 원본 id 복원
    }

    func testQuitActionAppendedToManifestAndRouted() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)
        sat.setActions([sat.makeAction(id: "deploy", title: "배포")])

        var quit = false
        var invoked: String?
        sat.onInvoke { invoked = $0 }
        sat.setQuitAction { quit = true }

        // 매니페스트 맨 뒤에 종료 액션이 붙는다
        XCTAssertTrue(sat.writeManifest())
        let decoded = try JSONDecoder().decode(
            MenubManifest.self,
            from: Data(contentsOf: MenubPaths.manifestURL(id: "runlet", in: dir))
        )
        XCTAssertEqual(decoded.actions.map(\.id), ["deploy", MenubSatellite.quitActionID])
        XCTAssertEqual(decoded.actions.last?.title, "종료")

        // 종료 액션 URL은 invokeHandler가 아니라 quitHandler로 가고, 매니페스트를 지운다
        let manifestURL = MenubPaths.manifestURL(id: "runlet", in: dir)
        XCTAssertTrue(sat.route(URL(string: sat.invokeString(for: MenubSatellite.quitActionID))!))
        XCTAssertTrue(quit)
        XCTAssertNil(invoked)
        XCTAssertFalse(FileManager.default.fileExists(atPath: manifestURL.path))  // 허브에서 사라짐
    }

    func testRouteRejectsForeignScheme() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)

        var invoked: String?
        sat.onInvoke { invoked = $0 }

        XCTAssertFalse(sat.route(URL(string: "other://action/deploy")!))
        XCTAssertNil(invoked)
    }

    func testObserveManagementFiresWhenManagedChanges() throws {
        let dir = makeTempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)

        let becameManaged = expectation(description: "관리 상태가 true로 바뀜")
        var states: [Bool] = []
        sat.observeManagement { managed in
            states.append(managed)
            if managed { becameManaged.fulfill() }
        }

        // 감시가 준비된 뒤 managed.json을 써서 관리 상태로 전환
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let data = try! JSONEncoder().encode(MenubManagedRegistry(managedIDs: ["runlet"]))
            try! data.write(to: dir.appendingPathComponent("managed.json"), options: .atomic)
        }

        wait(for: [becameManaged], timeout: 3)
        sat.stopObservingManagement()

        XCTAssertEqual(states.first, false)  // 처음엔 미관리
        XCTAssertEqual(states.last, true)    // 파일 쓰자 관리로 전환
    }

    func testIsManagedByHubReadsManagedFile() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)

        XCTAssertFalse(sat.isManagedByHub)  // 파일 없음
        XCTAssertTrue(sat.shouldCreateStatusItem())

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let managed = MenubManagedRegistry(managedIDs: ["runlet", "clip"])
        let data = try JSONEncoder().encode(managed)
        try data.write(to: dir.appendingPathComponent("managed.json"))

        XCTAssertTrue(sat.isManagedByHub)
        XCTAssertFalse(sat.shouldCreateStatusItem())
    }
}
