//
//  PopoverRootView.swift
//  Menub
//
//  기본 진입 UI. M1에서는 아직 위성 목록이 없어 빈 상태(placeholder)만 보여준다.
//  이후 M2에서 위성 그리드/리스트, M3에서 2뎁스 액션이 이 뷰에 붙는다.
//

import SwiftUI

struct PopoverRootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("menub")
                .font(.headline)

            Text("아직 등록된 도구가 없습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 260)
    }
}

#Preview {
    PopoverRootView()
}
