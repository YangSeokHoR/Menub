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

    func testRouteRejectsForeignScheme() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sat = makeSatellite(in: dir)

        var invoked: String?
        sat.onInvoke { invoked = $0 }

        XCTAssertFalse(sat.route(URL(string: "other://action/deploy")!))
        XCTAssertNil(invoked)
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
