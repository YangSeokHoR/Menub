//
//  MenubSatellite.swift
//  MenubKit
//
//  위성 앱이 menub 호환 계약 3가지를 붙이기 위한 진입점.
//   1) writeManifest()       — 매니페스트 기록
//   2) route(_:) + onInvoke  — URL scheme 핸들러
//   3) isManagedByHub        — 아이콘 숨김 체크
//  정적 메뉴/동적 명령을 모두 지원한다. invoke URL은 이 타입이 파생하므로 라우팅과 어긋나지 않는다.
//

import Foundation

public final class MenubSatellite {
    public let id: String
    public let displayName: String
    public let urlScheme: String
    public var bundleIdentifier: String?
    public var iconRef: String?

    private let baseDirectory: URL
    private var actions: [MenubAction] = []
    private var invokeHandler: ((String) -> Void)?
    private var managementSource: (any DispatchSourceFileSystemObject)?
    private var lastManagedState: Bool?

    /// - Parameter baseDirectory: 기본은 공유 폴더. 테스트에서 임시 폴더를 주입할 수 있다.
    public init(
        id: String,
        displayName: String,
        urlScheme: String,
        bundleIdentifier: String? = nil,
        iconRef: String? = nil,
        baseDirectory: URL = MenubPaths.directory
    ) {
        self.id = id
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.bundleIdentifier = bundleIdentifier
        self.iconRef = iconRef
        self.baseDirectory = baseDirectory
    }

    // MARK: - 액션

    /// id로 invoke URL을 파생해 액션을 만든다. (앱은 invoke 문자열을 직접 쓰지 않는다)
    public func makeAction(
        id: String,
        title: String,
        keywords: [String]? = nil,
        iconRef: String? = nil
    ) -> MenubAction {
        MenubAction(id: id, title: title, invoke: invokeString(for: id), keywords: keywords, iconRef: iconRef)
    }

    /// 액션 id에 대응하는 invoke URL 문자열. (`<scheme>://action/<id>`)
    /// id는 하나의 경로 세그먼트로 다루므로 `/`까지 인코딩한다(라우팅에서 세그먼트가 쪼개지지 않게).
    public func invokeString(for actionID: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let encoded = actionID.addingPercentEncoding(withAllowedCharacters: allowed) ?? actionID
        return "\(urlScheme)://action/\(encoded)"
    }

    /// 노출할 액션 목록을 통째로 설정한다. 동적 명령이면 바뀔 때마다 다시 호출한다.
    public func setActions(_ actions: [MenubAction]) {
        self.actions = actions
    }

    /// 현재 설정된 액션(디버깅/검증용).
    public var currentActions: [MenubAction] { actions }

    // MARK: - 계약 1: 매니페스트 기록

    /// 현재 정보/액션으로 매니페스트를 최신본으로 기록한다. 앱 시작 시와 액션 변경 시마다 호출.
    @discardableResult
    public func writeManifest() -> Bool {
        let manifest = MenubManifest(
            id: id,
            displayName: displayName,
            urlScheme: urlScheme,
            bundleIdentifier: bundleIdentifier,
            iconRef: iconRef,
            actions: actions
        )
        let url = MenubPaths.manifestURL(id: id, in: baseDirectory)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 계약 2: URL scheme 핸들러

    /// 액션이 호출됐을 때 실행할 핸들러. 인자는 액션 id. (정적: id로 switch, 동적: id로 명령 실행)
    public func onInvoke(_ handler: @escaping (String) -> Void) {
        invokeHandler = handler
    }

    /// 들어온 URL을 파싱해 onInvoke 핸들러로 넘긴다. onOpenURL/application(_:open:)에서 호출.
    /// id는 `<scheme>://action/` 접두사 뒤 전체를 하나로 취급해, id 안의 `/`가 세그먼트로 쪼개지지 않게 한다.
    @discardableResult
    public func route(_ url: URL) -> Bool {
        let prefix = "\(urlScheme)://action/"
        let string = url.absoluteString
        guard string.hasPrefix(prefix) else { return false }
        let encoded = String(string.dropFirst(prefix.count))
        guard !encoded.isEmpty else { return false }
        let actionID = encoded.removingPercentEncoding ?? encoded
        invokeHandler?(actionID)
        return true
    }

    // MARK: - 계약 3: 아이콘 숨김 체크

    /// 허브가 이 위성을 관리(아이콘 숨김) 중인지. 시작 시 읽어 상태 아이템 생성 여부를 결정한다.
    public var isManagedByHub: Bool {
        let url = MenubPaths.managedURL(in: baseDirectory)
        guard let data = try? Data(contentsOf: url),
              let registry = try? JSONDecoder().decode(MenubManagedRegistry.self, from: data) else {
            return false
        }
        return registry.managedIDs.contains(id)
    }

    /// 상태 아이템을 만들어야 하는가(= 허브가 관리하지 않는가).
    public func shouldCreateStatusItem() -> Bool {
        !isManagedByHub
    }

    /// managed.json 변경을 감시해 관리 상태가 바뀌면 즉시 콜백한다(재실행 없이 아이콘 숨김/표시).
    /// 콜백 인자는 "허브가 관리 중(=아이콘 숨김)"인지 여부. 메인 큐에서 호출된다.
    /// 처음 호출 시 현재 상태로 한 번 콜백한다.
    public func observeManagement(_ onChange: @escaping (Bool) -> Void) {
        stopObservingManagement()

        let current = isManagedByHub
        lastManagedState = current
        DispatchQueue.main.async { onChange(current) }

        // 원자적 쓰기(rename)까지 잡히도록 파일이 아니라 공유 폴더를 감시한다.
        let descriptor = open(baseDirectory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let now = self.isManagedByHub
            guard now != self.lastManagedState else { return }
            self.lastManagedState = now
            DispatchQueue.main.async { onChange(now) }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        managementSource = source
    }

    public func stopObservingManagement() {
        managementSource?.cancel()
        managementSource = nil
        lastManagedState = nil
    }
}
