//
//  LoginItem.swift
//  Menub
//
//  로그인 시 자동 실행. SMAppService로 이 앱을 로그인 항목에 등록/해제한다. (macOS 13+)
//

import ServiceManagement

enum LoginItem {
    /// 현재 로그인 항목으로 등록돼 활성인가.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 사용자 승인 대기 상태(시스템 설정 > 로그인 항목에서 켜야 함).
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// 로그인 항목 등록/해제. 성공 여부를 돌려준다.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("menub: 로그인 항목 변경 실패 — \(error.localizedDescription)")
            return false
        }
    }
}
