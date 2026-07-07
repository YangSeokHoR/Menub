//
//  PaletteView.swift
//  Menub
//
//  보조 진입 UI. 전 위성 액션을 하나의 평평한 목록으로 열람·검색·실행한다. (개발지침 §5, §9 M5)
//  열면 전체 액션이 보이고, 타이핑은 정의 어휘 안에서 필터만 하며, Enter는 하이라이트된
//  정의 액션만 실행한다. 맞는 게 없으면 조용히 검색어가 흔들린다.
//

import SwiftUI

struct PaletteView: View {
    let registry: RegistryStore
    let config: ConfigStore
    let invoker: Invoker
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection: Int?
    @State private var shake: CGFloat = 0
    @FocusState private var fieldFocused: Bool

    private var allItems: [PaletteItem] {
        PaletteSearch.items(
            manifests: registry.manifests,
            isEnabled: config.isEnabled,
            isPinned: config.isPinned
        )
    }

    private var result: PaletteSearch.Result {
        PaletteSearch.run(items: allItems, query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsArea
        }
        .frame(width: 620, height: 440)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
        .onAppear {
            fieldFocused = true
            selection = result.autoselect
        }
        .onChange(of: query) {
            selection = PaletteSearch.run(items: allItems, query: query).autoselect
        }
    }

    // MARK: - 검색 필드

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            TextField("액션 검색", text: $query)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($fieldFocused)
                .onSubmit(submit)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .modifier(ShakeEffect(animatableData: shake))
    }

    // MARK: - 결과

    @ViewBuilder
    private var resultsArea: some View {
        let items = result.items
        if items.isEmpty {
            VStack {
                Spacer()
                Text(query.isEmpty ? "허브에 켜진 도구가 없습니다." : "일치하는 액션이 없습니다.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            PaletteRow(item: item, isSelected: index == selection)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selection = index
                                    submit()
                                }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selection) {
                    if let selection { proxy.scrollTo(selection, anchor: .center) }
                }
            }
        }
    }

    // MARK: - 동작

    private func move(_ delta: Int) {
        let count = result.items.count
        guard count > 0 else { return }
        let current = selection ?? (delta > 0 ? -1 : count)
        selection = min(max(current + delta, 0), count - 1)
    }

    private func submit() {
        let items = result.items
        guard let selection, items.indices.contains(selection) else {
            triggerShake()
            return
        }
        invoker.invoke(items[selection].action)
        onClose()
    }

    private func triggerShake() {
        withAnimation(.linear(duration: 0.35)) { shake += 1 }
    }
}

/// 팔레트 결과 한 줄: 아이콘 + 액션 제목 + 앱 이름(어느 앱의 무슨 액션인지 자기설명).
private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImageName)
                .frame(width: 22)
                .foregroundStyle(isSelected ? .white : .secondary)
            Text(item.title)
                .foregroundStyle(isSelected ? .white : .primary)
            Spacer()
            Text(item.satelliteName)
                .font(.callout)
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

/// 검색어를 좌우로 짧게 흔드는 효과. (실행 대상이 없을 때 조용한 실패 신호)
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    var amplitude: CGFloat = 7
    var shakes: CGFloat = 3

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = amplitude * sin(animatableData * .pi * shakes * 2)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}
