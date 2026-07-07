//
//  MenubTests.swift
//  MenubTests
//
//  Created by seokho on 7/7/26.
//

import Testing
import Foundation
@testable import Menub

@MainActor
struct MenubTests {

    @Test func invokerOpensValidURL() throws {
        var openedURL: URL?
        let invoker = Invoker(openURL: { url in
            openedURL = url
            return true
        })
        let action = SatelliteAction(id: "deploy", title: "배포 실행", invoke: "runlet://run/deploy")

        let result = invoker.invoke(action)

        #expect(openedURL == URL(string: "runlet://run/deploy"))
        #expect(result == .opened(URL(string: "runlet://run/deploy")!))
    }

    @Test func invokerReportsFailureWhenOpenFails() throws {
        let invoker = Invoker(openURL: { _ in false })
        let action = SatelliteAction(id: "build", title: "빌드", invoke: "runlet://run/build")

        let result = invoker.invoke(action)

        #expect(result == .failed(URL(string: "runlet://run/build")!))
    }

    @Test func invokerRejectsInvalidURL() throws {
        var openCalled = false
        let invoker = Invoker(openURL: { _ in
            openCalled = true
            return true
        })
        // 빈 문자열은 URL로 만들 수 없다.
        let action = SatelliteAction(id: "bad", title: "잘못됨", invoke: "")

        let result = invoker.invoke(action)

        #expect(result == .invalidURL)
        #expect(openCalled == false)
    }
}
