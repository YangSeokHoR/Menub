//
//  MenubPaths.swift
//  MenubKit
//
//  공유 폴더 경로. 허브와 위성이 같은 위치를 본다(비샌드박스 전제).
//

import Foundation

public enum MenubPaths {
    /// `~/Library/Application Support/menub/`
    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("menub", isDirectory: true)
    }

    public static var manifestsDirectory: URL {
        directory.appendingPathComponent("manifests", isDirectory: true)
    }

    public static func managedURL(in base: URL = directory) -> URL {
        base.appendingPathComponent("managed.json", isDirectory: false)
    }

    public static func manifestURL(id: String, in base: URL = directory) -> URL {
        base.appendingPathComponent("manifests", isDirectory: true)
            .appendingPathComponent("\(id).json", isDirectory: false)
    }
}
