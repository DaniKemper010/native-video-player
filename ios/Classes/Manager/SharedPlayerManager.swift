import AVFoundation

// MARK: - Shared Player Manager

/// Manages shared AVPlayer instances across multiple platform views
/// Keeps players alive even when platform views are disposed
/// Note: Each platform view gets its own AVPlayerViewController, but they share the same AVPlayer
class SharedPlayerManager {
    static let shared = SharedPlayerManager()

    private var players: [Int: AVPlayer] = [:]

    private init() {}

    /// Gets or creates a player for the given controller ID
    func getOrCreatePlayer(for controllerId: Int) -> AVPlayer {
        if let existingPlayer = players[controllerId] {
            return existingPlayer
        }

        let newPlayer = AVPlayer()
        players[controllerId] = newPlayer
        return newPlayer
    }

    /// Removes a player (called when explicitly disposed)
    func removePlayer(for controllerId: Int) {
        players.removeValue(forKey: controllerId)
    }

    /// Clears all players (e.g., on logout)
    func clearAll() {
        players.removeAll()
    }
}
