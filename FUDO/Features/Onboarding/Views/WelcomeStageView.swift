import AVFoundation
import SwiftUI

/// The three welcome ambiences. Each carries its clip, its still fallback and how
/// it loops: 01a/01c start ≠ end (dissolve the seam), 01b is directional
/// (blue → vermillon) and only ever plays forward.
enum WelcomeClip: Equatable {
    case dojo, phone, doors

    var videoName: String {
        switch self {
        case .dojo: return "welcome-01a"
        case .phone: return "welcome-01b"
        case .doors: return "welcome-01c"
        }
    }

    var stillName: String {
        switch self {
        case .dojo: return "anchor-01a-dojo"
        case .phone: return "anchor-01b-phone"
        case .doors: return "anchor-01c-doors"
        }
    }

    var videoURL: URL? { Bundle.main.url(forResource: videoName, withExtension: "mp4") }
    var stillURL: URL? { Bundle.main.url(forResource: stillName, withExtension: "jpg") }
}

/// Full-bleed muted ambience under the welcome hooks (OB 00 → 01c).
///
/// TWO player layers, always. That single choice buys both things the brief asks
/// for, with no reverse playback anywhere:
///  - **the seam** (D5, Romain 2026-07-15): 01a and 01c start ≠ end, so a plain
///    loop would cut. Near the end, the idle layer restarts the same clip at 0 and
///    the two dissolve — the eye reads continuous motion. A true ping-pong needs
///    `rate = -1`, i.e. backwards H.264 decoding, which stutters on device.
///  - **the clip change** (01a → 01b → 01c): the new clip starts on the idle layer
///    and they cross-fade. The scene glides; it never blinks to black.
///
/// FALLBACK (built now, not later): missing asset, failed item, or Low Power Mode
/// → the still from Resources/Welcome/. Same cross-fades, zero decoding.
struct WelcomeStageView: View {
    let clip: WelcomeClip

    @Environment(\.scenePhase) private var scenePhase
    @State private var usesStill = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        GeometryReader { geometry in
            Group {
                if usesStill {
                    stillImage
                } else {
                    VideoStage(clip: clip, isActive: scenePhase == .active,
                               onFailure: { usesStill = true })
                }
            }
            // Media never overflows its stage (known-pitfalls list): the frame is
            // the geometry, `clipped` is the contract. No guessed padding.
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .animation(AppAnimation.standard, value: usesStill)
    }

    @ViewBuilder private var stillImage: some View {
        if let url = clip.stillURL, let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .transition(.opacity)
                .id(clip)
        } else {
            FudoColor.bgPrimary
        }
    }
}

// MARK: - The two-layer player

/// The AVFoundation half. Owns two `AVPlayerLayer`s and cross-fades between them;
/// SwiftUI never sees a player.
private struct VideoStage: UIViewRepresentable {
    let clip: WelcomeClip
    let isActive: Bool
    let onFailure: () -> Void

    func makeUIView(context: Context) -> CrossfadePlayerView {
        let view = CrossfadePlayerView()
        view.onFailure = onFailure
        view.show(clip, crossfading: false)
        return view
    }

    func updateUIView(_ view: CrossfadePlayerView, context: Context) {
        view.onFailure = onFailure
        view.show(clip, crossfading: true)
        isActive ? view.resume() : view.pause()
    }

    static func dismantleUIView(_ view: CrossfadePlayerView, coordinator: ()) {
        view.tearDown()
    }
}

/// Two layers, one visible. `show(_:crossfading:)` swaps clips; the seam watcher
/// dissolves the loop point. Nothing here decodes backwards.
final class CrossfadePlayerView: UIView {
    private struct Lane {
        let player = AVPlayer()
        let layer = AVPlayerLayer()
    }

    private let lanes = [Lane(), Lane()]
    private var front = 0
    private var currentClip: WelcomeClip?
    /// A boundary-observer token can only be removed from the player that created
    /// it — removing it from the other lane's player is an AVFoundation exception.
    private var seamObservation: (player: AVPlayer, token: Any)?
    /// Bumped on every watchSeam/tearDown: a stale async duration load must never
    /// register an observer for a seam that has already been replaced.
    private var seamGeneration = 0
    private var endObservers: [Int: NSObjectProtocol] = [:]
    private var isPaused = false
    var onFailure: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(FudoColor.bgPrimary)
        for lane in lanes {
            lane.player.isMuted = true          // ambience, never audio
            lane.player.actionAtItemEnd = .none
            lane.layer.player = lane.player
            lane.layer.videoGravity = .resizeAspectFill
            lane.layer.opacity = 0
            layer.addSublayer(lane.layer)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) unused") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // No implicit animation on bounds: a rotating/resizing layer must not
        // cross-fade its own geometry.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for lane in lanes { lane.layer.frame = bounds }
        CATransaction.commit()
    }

    // MARK: - Clip changes

    func show(_ clip: WelcomeClip, crossfading: Bool) {
        guard clip != currentClip else { return }
        currentClip = clip
        guard let url = clip.videoURL else {
            onFailure?()
            return
        }
        let next = (front + 1) % lanes.count
        load(url, intoLane: next)
        lanes[next].player.play()
        crossfade(to: next, animated: crossfading)
        watchSeam(of: lanes[next], url: url)
    }

    private func load(_ url: URL, intoLane index: Int) {
        let lane = lanes[index]
        if let previous = endObservers[index] {
            NotificationCenter.default.removeObserver(previous)
        }
        let item = AVPlayerItem(url: url)
        // Safety net, observed on THIS item only (object: nil would fire for every
        // item in the process): the front item reaching its natural end means the
        // seam never dissolved — degrade to the still, never freeze or crash.
        endObservers[index] = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.frontItemReachedEnd(item)
        }
        lane.player.replaceCurrentItem(with: item)
        lane.player.seek(to: .zero)
        // A failed item means no ambience at all — fall back to the still rather
        // than leave the hooks floating on black.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if item.status == .failed { self?.onFailure?() }
        }
    }

    private func frontItemReachedEnd(_ item: AVPlayerItem) {
        // The retiring lane legitimately plays out its tail mid-dissolve; only the
        // FRONT item ending means the loop failed.
        guard item === lanes[front].player.currentItem, !isPaused else { return }
        onFailure?()
    }

    private func crossfade(to lane: Int, animated: Bool) {
        let duration = animated ? OnboardingMetrics.videoCrossfade : 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        for (index, candidate) in lanes.enumerated() {
            candidate.layer.opacity = index == lane ? 1 : 0
        }
        CATransaction.commit()
        front = lane
    }

    // MARK: - The seam (D5)

    /// Restart the SAME clip on the idle lane one cross-fade before the end, and
    /// dissolve into it: the cut where start ≠ end becomes a fade.
    private func watchSeam(of lane: Lane, url: URL) {
        removeSeamObservation()
        seamGeneration += 1
        let generation = seamGeneration
        let asset = AVURLAsset(url: url)
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let duration = try? await asset.load(.duration), duration.isNumeric else {
                // No readable duration = no seam will ever fire: still, not a freeze.
                if generation == self.seamGeneration { self.onFailure?() }
                return
            }
            // A newer show()/seam replaced this watch while the duration loaded.
            guard generation == self.seamGeneration else { return }
            let seam = duration.seconds - OnboardingMetrics.videoCrossfade
            guard seam > 0 else {
                self.onFailure?()
                return
            }
            let time = CMTime(seconds: seam, preferredTimescale: 600)
            let token = lane.player.addBoundaryTimeObserver(
                forTimes: [NSValue(time: time)], queue: .main
            ) { [weak self] in
                self?.dissolveSeam(url: url)
            }
            self.seamObservation = (lane.player, token)
        }
    }

    private func removeSeamObservation() {
        guard let seamObservation else { return }
        seamObservation.player.removeTimeObserver(seamObservation.token)
        self.seamObservation = nil
    }

    private func dissolveSeam(url: URL) {
        guard !isPaused else { return }
        let next = (front + 1) % lanes.count
        load(url, intoLane: next)
        lanes[next].player.play()
        crossfade(to: next, animated: true)
        watchSeam(of: lanes[next], url: url)
    }

    // MARK: - Lifecycle

    func pause() {
        isPaused = true
        lanes.forEach { $0.player.pause() }
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        lanes[front].player.play()
    }

    func tearDown() {
        removeSeamObservation()
        seamGeneration += 1     // orphan any in-flight duration load
        for token in endObservers.values {
            NotificationCenter.default.removeObserver(token)
        }
        endObservers.removeAll()
        lanes.forEach {
            $0.player.pause()
            $0.player.replaceCurrentItem(with: nil)
        }
    }
}
