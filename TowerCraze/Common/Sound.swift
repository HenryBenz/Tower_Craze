import Foundation

/// Музыка и звуки отключены.
final class Sound {
    static let shared = Sound()

    private init() {}

    func playMusic(_ name: String = "music", volume: Float = 0.4) {}

    func setMusicVolume(_ volume: Float) {}

    func play(_ name: String, volume: Float = 0.9) {}
}
