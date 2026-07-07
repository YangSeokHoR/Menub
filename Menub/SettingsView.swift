//
//  SettingsView.swift
//  Menub
//
//  감지된 위성을 토글로 허브에 넣고 뺀다. 켜면 그 위성이 자기 메뉴바 아이콘을 숨긴다. (개발지침 §5, §9 M4)
//

import SwiftUI

struct SettingsView: View {
    let registry: RegistryStore
    let config: ConfigStore

    private var satellites: [SatelliteManifest] {
        registry.manifests.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("허브에 포함할 도구")
                .font(.headline)

            if satellites.isEmpty {
                Text("감지된 도구가 없습니다.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                List(satellites) { satellite in
                    row(for: satellite)
                }
                .listStyle(.inset)
                .frame(minHeight: 180)
            }

            Text("도구를 켜면 그 앱이 다음 실행부터 자기 메뉴바 아이콘을 숨기고, 끄면 다시 표시합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 380, height: 320)
        .onAppear { registry.load() }
    }

    private func row(for satellite: SatelliteManifest) -> some View {
        Toggle(isOn: enabledBinding(for: satellite.id)) {
            HStack(spacing: 10) {
                Image(systemName: satellite.systemImageName)
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(satellite.displayName)
                    Text("액션 \(satellite.actions.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func enabledBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { config.isEnabled(id) },
            set: { config.setEnabled(id, $0) }
        )
    }
}

#Preview {
    SettingsView(registry: RegistryStore(), config: ConfigStore())
}
