//
//  PopoverRootView.swift
//  Menub
//
//  기본 진입 UI. 위성 그리드(1뎁스) → 액션 목록(2뎁스)을 같은 패널에서 전환한다.
//  액션 클릭 시 Invoker가 URL로 실제 위성 기능을 호출한다. (개발지침 §5, §9 M3)
//

import SwiftUI

struct PopoverRootView: View {
    let registry: RegistryStore
    let config: ConfigStore
    var invoker = Invoker()

    // 선택된 위성 id. nil이면 루트 그리드, 값이 있으면 액션 목록(2뎁스).
    @State private var selectedID: String?

    // 팝오버 목록 = 가용 도구(RegistryStore) ∩ enabled(ConfigStore). 핀은 config 기준.
    private var sortedSatellites: [SatelliteManifest] {
        registry.manifests
            .filter { config.isEnabled($0.id) }
            .sorted { lhs, rhs in
                let lhsPinned = config.isPinned(lhs.id)
                let rhsPinned = config.isPinned(rhs.id)
                if lhsPinned != rhsPinned { return lhsPinned }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private var selectedSatellite: SatelliteManifest? {
        guard let selectedID else { return nil }
        return registry.manifests.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let satellite = selectedSatellite {
                ActionListView(
                    manifest: satellite,
                    invoker: invoker,
                    onBack: { selectedID = nil }
                )
            } else {
                rootView
            }
        }
        .frame(width: 300)
        .onAppear { registry.load() }
    }

    // MARK: - 루트 (위성 그리드)

    private var rootView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if sortedSatellites.isEmpty {
                emptyState
            } else {
                grid
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(.secondary)
            Text("menub")
                .font(.headline)
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("설정")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 84), spacing: 12)],
            spacing: 12
        ) {
            ForEach(sortedSatellites) { satellite in
                SatelliteTile(
                    manifest: satellite,
                    isPinned: config.isPinned(satellite.id),
                    onSelect: { selectedID = satellite.id }
                )
            }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("허브에 켜진 도구가 없습니다.\n설정에서 도구를 켜 보세요.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SettingsLink {
                Text("설정 열기")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
}

/// 위성 하나를 나타내는 그리드 타일. 탭하면 액션 목록으로 전환. (아이콘 + 이름, 핀 표시)
private struct SatelliteTile: View {
    let manifest: SatelliteManifest
    let isPinned: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: manifest.systemImageName)
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }

                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(4)
                    }
                }

                Text(manifest.displayName)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
        .help(manifest.displayName)
    }
}

/// 2뎁스: 선택된 위성의 액션 목록. 액션 클릭 시 Invoker로 URL 호출.
private struct ActionListView: View {
    let manifest: SatelliteManifest
    let invoker: Invoker
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if manifest.actions.isEmpty {
                Text("실행할 액션이 없습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 2) {
                    ForEach(manifest.actions) { action in
                        ActionRow(action: action) {
                            invoker.invoke(action)
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .help("뒤로")

            Image(systemName: manifest.systemImageName)
                .foregroundStyle(.secondary)
            Text(manifest.displayName)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

/// 액션 한 줄. 탭하면 onInvoke 실행.
private struct ActionRow: View {
    let action: SatelliteAction
    let onInvoke: () -> Void

    var body: some View {
        Button(action: onInvoke) {
            HStack(spacing: 10) {
                Image(systemName: action.systemImageName)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(action.title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PopoverRootView(registry: RegistryStore(), config: ConfigStore())
}
