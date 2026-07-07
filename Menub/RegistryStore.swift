//
//  RegistryStore.swift
//  Menub
//
//  가용 도구의 진실원천. 공유 폴더의 매니페스트를 읽고, 폴더 변경을 감시해
//  자동으로 목록을 갱신한다. (개발지침 §6, §8-4)
//  뷰에 의존하지 않는다.
//

import Foundation
import Observation

@Observable
final class RegistryStore {
    /// 폴더에서 읽어들인 가용 위성 목록. 정렬/필터는 상위(뷰/ConfigStore)의 책임.
    private(set) var manifests: [SatelliteManifest] = []

    /// `~/Library/Application Support/menub/manifests/` (비샌드박스 전제)
    let manifestsDirectory: URL

    @ObservationIgnored private var watchSource: (any DispatchSourceFileSystemObject)?

    init(manifestsDirectory: URL? = nil) {
        self.manifestsDirectory = manifestsDirectory ?? Self.defaultManifestsDirectory()
        ensureDirectoryExists()
        load()
        startWatching()
    }

    deinit {
        watchSource?.cancel()
    }

    /// 공유 매니페스트 디렉터리 경로를 계산한다.
    static func defaultManifestsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("menub/manifests", isDirectory: true)
    }

    /// 폴더의 모든 `*.json`을 읽어 매니페스트 목록을 새로 채운다. 개별 파싱 실패는 건너뛴다.
    func load() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: manifestsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            manifests = []
            return
        }
        let decoder = JSONDecoder()
        manifests = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(SatelliteManifest.self, from: data)
            }
    }

    /// 해당 위성의 매니페스트 파일을 지워 감지 목록에서 제거한다.
    /// (그 위성 앱이 다시 실행되면 계약대로 스스로 매니페스트를 다시 기록한다)
    func deleteManifest(id: String) {
        let url = manifestsDirectory.appendingPathComponent("\(id).json", isDirectory: false)
        try? FileManager.default.removeItem(at: url)
        load()
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: manifestsDirectory,
            withIntermediateDirectories: true
        )
    }

    /// 매니페스트 폴더에 변경이 생기면 `load()`를 다시 돌린다. (위성이 매니페스트를 갱신하면 자동 반영)
    private func startWatching() {
        let descriptor = open(manifestsDirectory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.load() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watchSource = source
    }
}
