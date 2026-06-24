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
/// No CarPlay entitlement is required: any app that plays background audio and populates
/// `MPNowPlayingInfoCenter` shows up there automatically.
@MainActor
final class AmbientAudio {

    /// Called when the user taps play/pause from the car or lock screen. Wired to `Store.toggle()`.
    var onRemoteToggle: (() -> Void)?

    private var player: AVAudioPlayer?
    private var configured = false

    var isPlaying: Bool { player?.isPlaying ?? false }

    // MARK: Session control

    /// Begin (or resume) the ambient bed and publish Now Playing info.
    func start(activityName: String, accentHex: String, goalSeconds: TimeInterval, doneSeconds: TimeInterval) {
        configureIfNeeded()
        loadPlayerIfNeeded()
        guard let player else { return }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        if !player.isPlaying { player.play() }
        publishNowPlaying(activityName: activityName, accentHex: accentHex,
                          goalSeconds: goalSeconds, doneSeconds: doneSeconds, playing: true)
    }

    /// Stop the ambient bed and clear the Now Playing slot.
    func stop() {
        player?.pause()
        player?.currentTime = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    // MARK: Setup

    private func loadPlayerIfNeeded() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "Stillness", withExtension: "m4a") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1   // seamless infinite loop
        player?.prepareToPlay()
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        #endif

        let center = MPRemoteCommandCenter.shared()
        let toggle: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { [weak self] _ in
            self?.onRemoteToggle?()
            return .success
        }
        center.playCommand.addTarget(handler: toggle)
        center.pauseCommand.addTarget(handler: toggle)
        center.togglePlayPauseCommand.addTarget(handler: toggle)

        // Nothing to skip or seek in an ambient bed — keep the car controls minimal.
        for command in [center.nextTrackCommand, center.previousTrackCommand,
                        center.changePlaybackPositionCommand, center.seekForwardCommand,
                        center.seekBackwardCommand] {
            command.isEnabled = false
        }
    }

    // MARK: Now Playing

    private func publishNowPlaying(activityName: String, accentHex: String,
                                   goalSeconds: TimeInterval, doneSeconds: TimeInterval, playing: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: activityName,
            MPMediaItemPropertyArtist: "Focus",
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]

        // Map the day's progress onto the scrubber: a quiet bar that fills toward the goal.
        if goalSeconds > 0, doneSeconds < goalSeconds {
            info[MPMediaItemPropertyPlaybackDuration] = goalSeconds
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, doneSeconds)
        }

        #if canImport(UIKit)
        if let art = Self.artwork(activityName: activityName, accentHex: accentHex) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        #endif

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    #if canImport(UIKit)
    /// A calm, on-brand card for the lock screen / CarPlay artwork.
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
