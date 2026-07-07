//
//  SettingsView.swift
//  Menub
//
//  위성을 허브에 넣고 빼고(토글), 상단 고정(핀)·순서(드래그)를 정하고, 실행 상태를 보고,
//  팔레트 전역 단축키를 바꾼다. (개발지침 §5, §9 M4/M6)
//

import SwiftUI

struct SettingsView: View {
    let registry: RegistryStore
    let config: ConfigStore
    let runtime: RuntimeMonitor

    @State private var loginEnabled = LoginItem.isEnabled

    // 설정 목록은 사용자가 정한 순서(sortIndex → 이름)대로 보여, 드래그가 그대로 반영되게 한다.
    // (팝오버/팔레트는 여기에 더해 핀을 맨 위로 띄운다)
    private var orderedSatellites: [SatelliteManifest] {
        registry.manifests.sorted { lhs, rhs in
            let ls = config.sortIndex(lhs.id), rs = config.sortIndex(rhs.id)
            if ls != rs { return ls < rs }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            toolsSection
            Divider()
            hotkeySection
            Divider()
            generalSection
        }
        .padding(20)
        .frame(width: 420, height: 540)
        .onAppear {
            registry.load()
            loginEnabled = LoginItem.isEnabled
        }
    }

    // MARK: - 도구 목록

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("허브에 포함할 도구")
                .font(.headline)

            if orderedSatellites.isEmpty {
                Text("감지된 도구가 없습니다.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                List {
                    ForEach(orderedSatellites) { satellite in
                        row(for: satellite)
                            .contextMenu {
                                Button("허브에서 삭제", role: .destructive) {
                                    delete(satellite.id)
                                }
                            }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 220)
            }

            Text("드래그로 순서를 바꾸고, 핀으로 맨 위에 고정합니다. 켜면 그 앱이 다음 실행부터 자기 메뉴바 아이콘을 숨깁니다. 스와이프(또는 우클릭)로 삭제하면 허브에서 빠지고 그 앱은 자기 아이콘을 다시 표시합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func row(for satellite: SatelliteManifest) -> some View {
        HStack(spacing: 10) {
            Image(systemName: satellite.systemImageName)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(satellite.displayName)
                    if runtime.isRunning(satellite.bundleIdentifier) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                            .help("실행 중")
                    }
                }
                Text("액션 \(satellite.actions.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                config.setPinned(satellite.id, !config.isPinned(satellite.id))
            } label: {
                Image(systemName: config.isPinned(satellite.id) ? "pin.fill" : "pin")
                    .foregroundStyle(config.isPinned(satellite.id) ? .orange : .secondary)
            }
            .buttonStyle(.borderless)
            .help(config.isPinned(satellite.id) ? "고정 해제" : "맨 위에 고정")

            Toggle("", isOn: enabledBinding(for: satellite.id))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ids = orderedSatellites.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        config.setOrder(ids)
    }

    /// 허브에서 삭제: 설정 제거(관리 해제 → 아이콘 복귀) + 매니페스트 삭제(목록에서 제거).
    private func delete(_ id: String) {
        config.remove(id)
        registry.deleteManifest(id: id)
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { orderedSatellites[$0].id }.forEach(delete)
    }

    private func enabledBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { config.isEnabled(id) },
            set: { config.setEnabled(id, $0) }
        )
    }

    // MARK: - 단축키

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("검색 팔레트 단축키")
                .font(.headline)
            HStack(spacing: 12) {
                HotkeyRecorderView(current: config.effectiveHotkey) { hotkey in
                    config.setPaletteHotkey(hotkey)
                }
                Button("기본값") { config.setPaletteHotkey(nil) }
                    .disabled(config.config.paletteHotkey == nil)
                Spacer()
            }
            Text("전역에서 이 조합을 누르면 검색 팔레트가 열립니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 일반

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("일반")
                .font(.headline)
            Toggle("로그인 시 자동 실행", isOn: Binding(
                get: { loginEnabled },
                set: { on in loginEnabled = LoginItem.setEnabled(on) ? on : LoginItem.isEnabled }
            ))
            if LoginItem.requiresApproval {
                Text("시스템 설정 › 일반 › 로그인 항목에서 menub를 허용해야 적용됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 단축키 레코더: 클릭하면 다음 키 조합을 잡아 저장한다. (로컬 이벤트 모니터, 접근성 권한 불필요)
private struct HotkeyRecorderView: View {
    let current: Hotkey
    let onRecorded: (Hotkey) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(isRecording ? "키 입력을 기다리는 중… (⎋ 취소)" : current.display)
                .frame(minWidth: 160)
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(53) {  // Esc
                stop()
                return nil
            }
            if let hotkey = Hotkey(event: event) {
                onRecorded(hotkey)
                stop()
            }
            return nil  // 이벤트 소비(다른 곳으로 안 흘려보냄)
        }
    }

    private func stop() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

#Preview {
    SettingsView(registry: RegistryStore(), config: ConfigStore(), runtime: RuntimeMonitor())
}
