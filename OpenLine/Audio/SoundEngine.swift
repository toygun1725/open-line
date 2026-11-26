import AVFoundation
import Foundation

@MainActor
final class SoundEngine {
    var isMuted: Bool = false
    private var players: [String: AVAudioPlayer] = [:]

    init() {
        configureAudioSession()
        preload(names: ["click1", "click2", "switch2", "rollover1"])
    }

    func playClick() {
        play(name: "click2", volume: 0.45)
    }

    func playSwitch() {
        play(name: "switch2", volume: 0.55)
    }

    func playIncomingMessage() {
        let name = Bool.random() ? "click1" : "rollover1"
        play(name: name, volume: 0.35)
    }

    private func configureAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    private func preload(names: [String]) {
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav")
                ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    players[name] = player
                }
            }
        }
    }

    private func play(name: String, volume: Float) {
        guard !isMuted, let player = players[name] else { return }
        player.currentTime = 0
        player.volume = volume
        player.play()
    }
}
