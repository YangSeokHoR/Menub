//
//  PopoverRootView.swift
//  Menub
//
//  기본 진입 UI. 가용 위성을 그리드로 보여준다. Runlet은 맨 위 고정. (개발지침 §5, §9 M2)
//  액션 2뎁스 전환과 실제 호출은 M3에서 붙는다.
//

import SwiftUI

struct PopoverRootView: View {
    let registry: RegistryStore

    // M2 임시 규칙: Runlet(id "runlet")을 핀으로 간주해 맨 위 고정.
    // 사용자별 pinned/enabled/sortIndex의 영속 저장(ConfigStore)은 M4/M6에서 도입.
    private static let pinnedID = "runlet"

    private var sortedSatellites: [SatelliteManifest] {
        registry.manifests.sorted { lhs, rhs in
            let lhsPinned = lhs.id == Self.pinnedID
            let rhsPinned = rhs.id == Self.pinnedID
            if lhsPinned != rhsPinned { return lhsPinned }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if sortedSatellites.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .frame(width: 300)
        .onAppear { registry.load() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(.secondary)
            Text("menub")
                .font(.headline)
            Spacer()
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
                    isPinned: satellite.id == Self.pinnedID
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
            Text("아직 등록된 도구가 없습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
}

/// 위성 하나를 나타내는 그리드 타일. (아이콘 + 이름, 핀 표시)
private struct SatelliteTile: View {
    let manifest: SatelliteManifest
    let isPinned: Bool

    var body: some View {
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
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 76)
        .help(manifest.displayName)
    }
}

#Preview {
    PopoverRootView(registry: RegistryStore())
}
