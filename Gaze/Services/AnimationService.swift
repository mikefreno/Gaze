//
//  AnimationService.swift
//  Gaze
//
//  Created by Mike Freno on 1/9/26.
//

import Foundation

@MainActor
class AnimationService {
    static let shared = AnimationService()

    private init() {}

    struct RemoteAnimation: Codable {
        let name: String
        let version: String
        let date: String  // ISO 8601 formatted date string

        enum CodingKeys: String, CodingKey {
            case name, version, date
        }
    }

    struct RemoteAnimationsResponse: Codable {
        let animations: [RemoteAnimation]
    }

    // MARK: - Public Methods

    func fetchRemoteAnimations() async throws -> [RemoteAnimation] {
        guard let url = URL(string: "https://freno.me/api/Gaze/animations") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        do {
            let decoder = JSONDecoder()
            let remoteAnimations = try decoder.decode(RemoteAnimationsResponse.self, from: data)
            return remoteAnimations.animations
        } catch {
            throw error
        }
    }

    func updateLocalAnimationsIfNeeded(remoteAnimations: [RemoteAnimation]) async throws {
        // For now, just validate the API response structure.
        // In a real implementation, this would:
        // 1. Compare dates of local vs remote animations
        // 2. Update local files if newer versions exist
        // 3. Tag local files with date fields in ISO 8601 format

        for animation in remoteAnimations {
            print("Remote animation: \(animation.name) - \(animation.version) - \(animation.date)")
        }
    }
}

