import Foundation
import AVFoundation
import MediaPlayer
#if canImport(UIKit)
import SwiftUI
import UIKit
#endif

/// Plays the looping "Stillness" ambient bed during a focus session and mirrors the
/// session onto the system Now Playing screen — the lock screen and, over CarPlay or
/// Bluetooth, the car's display. The car's play/pause maps back to starting and pausing
/// the session, and the Now Playing scrubber doubles as a subtle progress-toward-goal bar.
///
/// All audio-engine work (decoding the file, activating the session, play/pause) runs on a
/// private serial queue so the Start button updates instantly — activating an audio session
/// on the main thread can stall for hundreds of ms, which made Start feel like it needed a
/// couple of presses. No CarPlay entitlement is required: any app that plays background
/// audio and populates `MPNowPlayingInfoCenter` shows up there automatically.
final class AmbientAudio: @unchecked Sendable {

    /// Tapped play/pause/toggle from the car or lock screen. Wired to `Store` start/stop/toggle.
    var onRemotePlay: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteToggle: (() -> Void)?

    private let queue = DispatchQueue(label: "com.brandonnelson.focus.ambient")
    private var player: AVAudioPlayer?   // touched only on `queue`
    private var commandsConfigured = false  // touched only on the main thread
    private var generation = 0              // touched only on the main thread

    // MARK: Lifecycle

    /// Pre-load the player and register remote commands so the first Start has no latency.
    /// Safe to call repeatedly. Call when sound is enabled and at launch if it's already on.
    func prewarm() {
        configureCommandsIfNeeded()
        queue.async { [weak self] in self?.ensurePlayer() }
    }

    /// Begin (or resume) the ambient bed and publish Now Playing info. Returns immediately;
    /// the engine spins up off the main thread.
    func start(activityName: String, accentHex: String, goalSeconds: TimeInterval, doneSeconds: TimeInterval) {
        configureCommandsIfNeeded()
        generation &+= 1
        publishNowPlaying(activityName: activityName, accentHex: accentHex,
                          goalSeconds: goalSeconds, doneSeconds: doneSeconds, generation: generation)

        queue.async { [weak self] in
            guard let self else { return }
            self.ensurePlayer()
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
            #endif
            if self.player?.isPlaying == false {
                self.player?.currentTime = 0
                self.player?.play()
            }
        }
    }

    /// Stop the ambient bed and clear the Now Playing slot.
    func stop() {
        generation &+= 1
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        queue.async { [weak self] in
            guard let self else { return }
            self.player?.pause()
            self.player?.currentTime = 0
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            #endif
        }
    }

    // MARK: Engine (queue-isolated)

    private func ensurePlayer() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "Stillness", withExtension: "m4a") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1   // seamless infinite loop
        player?.prepareToPlay()
    }

    // MARK: Remote commands (main thread)

    private func configureCommandsIfNeeded() {
        guard !commandsConfigured else { return }
        commandsConfigured = true

        let center = MPRemoteCommandCenter.shared()
        // State-aware so a stray system play/pause can't flip the session the wrong way.
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onRemotePlay?() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onRemotePause?() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onRemoteToggle?() }
            return .success
        }

        // Nothing to skip or seek in an ambient bed — keep the car controls minimal.
        for command in [center.nextTrackCommand, center.previousTrackCommand,
                        center.changePlaybackPositionCommand, center.seekForwardCommand,
                        center.seekBackwardCommand] {
            command.isEnabled = false
        }
    }

    // MARK: Now Playing (main thread)

    private func publishNowPlaying(activityName: String, accentHex: String,
                                   goalSeconds: TimeInterval, doneSeconds: TimeInterval, generation gen: Int) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: activityName,
            MPMediaItemPropertyArtist: "Focus",
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]

        // Map the day's progress onto the scrubber: a quiet bar that fills toward the goal.
        if goalSeconds > 0, doneSeconds < goalSeconds {
            info[MPMediaItemPropertyPlaybackDuration] = goalSeconds
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, doneSeconds)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Artwork rendering isn't instant, so do it after the text is up and only apply it
        // if this session is still the current one (guards against a quick start→stop).
        #if canImport(UIKit)
        Task { @MainActor in
            guard self.generation == gen, let art = Self.artwork(activityName: activityName, accentHex: accentHex) else { return }
            guard self.generation == gen, var current = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
            current[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = current
        }
        #endif
    }

    #if canImport(UIKit)
    /// A calm, on-brand card for the lock screen / CarPlay artwork.
    @MainActor
    private static func artwork(activityName: String, accentHex: String) -> UIImage? {
        let renderer = ImageRenderer(content: NowPlayingArtwork(activityName: activityName, accentHex: accentHex))
        renderer.scale = 3
        return renderer.uiImage
    }
    #endif
}

#if canImport(UIKit)
/// The square shown on the lock screen and in the car while a session runs.
private struct NowPlayingArtwork: View {
    let activityName: String
    let accentHex: String

    var body: some View {
        ZStack {
            Color(hex: "101C2C")
            Circle()
                .stroke(Color(hex: accentHex).opacity(0.9), lineWidth: 6)
                .frame(width: 150, height: 150)
            VStack(spacing: 10) {
                Text(activityName)
                    .font(.sditDisplay(34))
                    .foregroundStyle(Color(hex: "F0EFE8"))
                Text("FOCUS")
                    .font(.sditMono(13))
                    .tracking(5)
                    .foregroundStyle(Color(hex: "5A6472"))
            }
        }
        .frame(width: 600, height: 600)
    }
}
#endif
