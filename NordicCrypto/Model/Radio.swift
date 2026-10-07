#if os(tvOS)
import AVFoundation
import Observation

/// Radio Norge in the background of the Apple TV app. On by default; the
/// viewer's choice is remembered.
@MainActor
@Observable
final class Radio {
    static let stream = URL(string: "https://live-bauerno.sharp-stream.com/radionorge_no_mp3")!
    static let name = "Radio Norge"
    private static let key = "radio.on"

    private(set) var isOn: Bool
    private(set) var isPlaying = false
    /// True while something else (the newsreel) has the sound.
    private var yielded = false
    private var player: AVPlayer?
    private var watchdog: Task<Void, Never>?

    init() {
        isOn = UserDefaults.standard.object(forKey: Self.key) as? Bool ?? true
    }

    func start() {
        if isOn && !yielded { play() }
        watchdog?.cancel()
        // Live streams drop; reconnect whenever the radio should be playing but is not.
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { return }
                if self.isOn && !self.yielded && self.player?.timeControlStatus != .playing { self.play() }
            }
        }
    }

    func toggle() {
        isOn.toggle()
        UserDefaults.standard.set(isOn, forKey: Self.key)
        if isOn && !yielded { play() } else { stop() }
    }

    /// Pause for other audio, e.g. while the newsreel plays.
    func yield(_ value: Bool) {
        yielded = value
        if value { stop() } else if isOn { play() }
    }

    private func play() {
        // Activating the session can block; keep it off the main thread.
        Task.detached(priority: .userInitiated) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        // A fresh item each time, so playback rejoins the live edge.
        let player = AVPlayer(url: Self.stream)
        player.automaticallyWaitsToMinimizeStalling = true
        player.play()
        self.player?.pause()
        self.player = player
        isPlaying = true
    }

    private func stop() {
        player?.pause()
        player = nil
        isPlaying = false
    }
}
#endif
