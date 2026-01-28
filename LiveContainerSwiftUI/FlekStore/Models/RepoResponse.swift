//
//  RepoResponse.swift
//  LiveContainer
//
//  Created by Alexander Grigoryev on 28.01.2026.
//

import Foundation

struct RepoResponse: Codable {
    let apps: [RepoApp]
}

struct RepoApp: Codable {
    let name: String
    let version: String
    let localizedDescription: String
    let iconURL: String
    let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case localizedDescription
        case iconURL
        case downloadURL
    }
}
