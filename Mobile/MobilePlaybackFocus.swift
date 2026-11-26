import AVFoundation
import SwiftUI

/// Keeps exactly one video stream playing.
///
/// Every surface that can play (the player page, the long-press feed preview,
/// the live room, the anime page) claims this focus right before it starts.
/// Claiming pauses whoever held it; releasing hands the sound back to the
/// surface that was playing before, so a preview opened over a running video
/// does not leave two streams going at once.
@MainActor
final class MobilePlaybackFocus {
    static let shared = MobilePlaybackFocus()

    private struct Claim {
        let id: ObjectIdentifier
        weak var owner: AnyObject?
        /// Pauses the surface if it is playing; returns whether it was.
        let pause: () -> Bool
        /// Resumes playback that this focus paused.
        let resume: () -> Void
        var suspended = false
    }

    private var claims: [Claim] = []
    private var isResuming = false
    /// While a claim is taking over, a surface that pauses itself on the way
    /// out must not hand the focus back to someone the newcomer is replacing.
    private var isActivating = false

    private init() {}

    /// Makes `owner` the one surface allowed to play.
    func activate(
        _ owner: AnyObject,
        pause: @escaping () -> Bool,
        resume: @escaping () -> Void
    ) {
        prune()
        isActivating = true
        defer { isActivating = false }
        let id = ObjectIdentifier(owner)
        claims.removeAll { $0.id == id }
        for index in claims.indices where !claims[index].suspended {
            claims[index].suspended = claims[index].pause()
            #if DEBUG
            if claims[index].suspended, let held = claims[index].owner {
                btbDebugLog("focus: suspended \(String(describing: type(of: held)))")
            }
            #endif
        }
        claims.append(Claim(id: id, owner: owner, pause: pause, resume: resume, suspended: false))
        #if DEBUG
        btbDebugLog("focus: \(String(describing: type(of: owner))) now playing")
        #endif
    }

    /// Gives the focus up. Whoever this claim paused is resumed.
    func deactivate(_ owner: AnyObject) {
        let id = ObjectIdentifier(owner)
        guard claims.contains(where: { $0.id == id }) else { return }
        claims.removeAll { $0.id == id }
        #if DEBUG
        btbDebugLog("focus: release \(String(describing: type(of: owner)))")
        #endif
        resumeSuspended()
    }

    /// Plain `AVPlayer` surfaces (live, anime): the only state to keep in
    /// step is the view's own `isPlaying` flag.
    func activate(player: AVPlayer, isPlaying: Binding<Bool>) {
        activate(
            player,
            pause: {
                // `.waitingToPlayAtSpecifiedRate` still counts as playing:
                // pausing then is what keeps a buffering stream from starting
                // under another one.
                guard player.timeControlStatus != .paused else { return false }
                player.pause()
                isPlaying.wrappedValue = false
                return true
            },
            resume: {
                player.play()
                isPlaying.wrappedValue = true
            }
        )
    }

    private func resumeSuspended() {
        guard !isResuming, !isActivating else { return }
        prune()
        guard let index = claims.lastIndex(where: \.suspended) else { return }
        claims[index].suspended = false
        isResuming = true
        claims[index].resume()
        isResuming = false
    }

    private func prune() {
        claims.removeAll { $0.owner == nil }
    }
}
