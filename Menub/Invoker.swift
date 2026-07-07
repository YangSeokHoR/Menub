//
//  Invoker.swift
//  Menub
//
//  액션 실행 코어. 앱 특정 지식 없이 invoke URL을 열기만 한다. (개발지침 §6)
//  URL scheme을 열면 LaunchServices가 해당 위성 앱을 실행하고 URL을 전달한다. (§8-3)
//  뷰에 의존하지 않는다.
//

import AppKit

enum InvokeResult: Equatable {
    case opened(URL)
    case failed(URL)
    case invalidURL
}

struct Invoker {
    /// URL을 여는 동작. 기본은 NSWorkspace로 실제 열기, 테스트에서 주입 가능.
    var openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) }

    /// 액션의 invoke 문자열을 URL로 열어 위성 기능을 호출한다.
    @discardableResult
    func invoke(_ action: SatelliteAction) -> InvokeResult {
        guard let url = URL(string: action.invoke) else {
            return .invalidURL
        }
        return openURL(url) ? .opened(url) : .failed(url)
    }
}
