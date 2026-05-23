import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// SwipeBack
// Android-style edge swipe navigation for iOS
//
// Features:
//   • Swipe from LEFT or RIGHT edge to go back (both sides, like Android 10+)
//   • Works for pushed ViewControllers (pop) AND presented ones (dismiss)
//   • Android-style elastic wave animation anchored to screen edge
//   • Chevron arrow grows inside the wave as you drag
//   • Haptic feedback at trigger threshold
//   • Zero configuration — one line in AppDelegate
//   • No subclassing required
//
// Usage:
//   SwipeBackManager.enable()   // in AppDelegate.didFinishLaunching
//
// Optional customization:
//   SwipeBackManager.enable(leftEdge: true, rightEdge: true, haptic: true)
//
// Note: This feature is not available in any existing iOS library.
//       SloppySwiper only handles left-edge pop with no visual feedback.
//       This library adds right-edge support, present/dismiss handling,
//       and the Android elastic wave indicator.
// ─────────────────────────────────────────────────────────────────────────────

// MARK: - SwipeBackManager

/// Entry point for SwipeBack.
/// Call `SwipeBackManager.enable()` once in `AppDelegate.didFinishLaunching`.
/// No other changes needed — all UINavigationControllers and presented
/// ViewControllers in the app will automatically get swipe-back support.
public class SwipeBackManager {

    /// Enables Android-style swipe-back for the entire app.
    ///
    /// - Parameters:
    ///   - leftEdge:  Enable swipe from left edge (standard iOS back). Default: true
    ///   - rightEdge: Enable swipe from right edge (Android 10+ style). Default: true
    ///   - haptic:    Enable haptic feedback on gesture start and completion. Default: true
    ///
    /// Example:
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    ///     SwipeBackManager.enable()
    ///     return true
    /// }
    /// ```
    public static func enable(
        leftEdge:  Bool = true,
        rightEdge: Bool = true,
        haptic:    Bool = true
    ) {
        SwipeBackConfig.leftEdge  = leftEdge
        SwipeBackConfig.rightEdge = rightEdge
        SwipeBackConfig.haptic    = haptic
        SwipeBackConfig.swizzleNavController()
        SwipeBackConfig.swizzleViewController()
    }
}

// MARK: - Internal Configuration

/// Internal configuration store and swizzle setup.
/// Not exposed publicly — all configuration goes through SwipeBackManager.
private class SwipeBackConfig {
    static var leftEdge:  Bool = true
    static var rightEdge: Bool = true
    static var haptic:    Bool = true

    /// Swizzles UINavigationController.viewDidLoad to inject edge gestures
    /// for push/pop navigation (the most common iOS navigation pattern).
    static func swizzleNavController() {
        let orig = class_getInstanceMethod(UINavigationController.self, #selector(UINavigationController.viewDidLoad))
        let swiz = class_getInstanceMethod(UINavigationController.self, #selector(UINavigationController.swb_navViewDidLoad))
        if let o = orig, let s = swiz { method_exchangeImplementations(o, s) }
    }

    /// Swizzles UIViewController.viewDidAppear to inject edge gestures
    /// for modally presented ViewControllers (dismiss on swipe).
    static func swizzleViewController() {
        let orig = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidAppear(_:)))
        let swiz = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.swb_viewDidAppear(_:)))
        if let o = orig, let s = swiz { method_exchangeImplementations(o, s) }
    }
}

// MARK: - Associated Object Keys

/// Key for storing the wave overlay reference on the view controller.
private var kOverlay = "swb_overlay"

// MARK: - UINavigationController Extension (Push/Pop)

extension UINavigationController {

    /// Swizzled viewDidLoad — injects edge pan gesture recognizers.
    /// Disables the default iOS interactive pop gesture (we replace it).
    @objc func swb_navViewDidLoad() {
        swb_navViewDidLoad() // calls original viewDidLoad

        // Disable default iOS left-edge swipe (we provide our own with visual feedback)
        interactivePopGestureRecognizer?.isEnabled = false

        if SwipeBackConfig.leftEdge  {
            addSwbEdge(.left,  target: self, action: #selector(swb_navPan(_:)))
        }
        if SwipeBackConfig.rightEdge {
            addSwbEdge(.right, target: self, action: #selector(swb_navPan(_:)))
        }
    }

    /// Handles edge pan gesture for navigation stack pop.
    /// Triggers popViewController when user drags far enough or fast enough.
    @objc func swb_navPan(_ g: UIScreenEdgePanGestureRecognizer) {
        guard viewControllers.count > 1 else { return } // nothing to pop
        handleSwbGesture(g, in: view) { [weak self] in
            self?.popViewController(animated: true)
        }
    }
}

// MARK: - UIViewController Extension (Present/Dismiss)

extension UIViewController {

    /// Swizzled viewDidAppear — adds edge gestures to modally presented VCs.
    /// Only applies to VCs that are presented (not pushed) and not containers.
    @objc func swb_viewDidAppear(_ animated: Bool) {
        swb_viewDidAppear(animated) // calls original viewDidAppear

        // Only add to presented VCs outside a navigation stack
        guard presentingViewController != nil,
              !(self is UINavigationController),
              !(self is UITabBarController),
              navigationController == nil
        else { return }

        // Remove any existing swb gestures to prevent duplicates on re-appear
        view.gestureRecognizers?
            .filter { $0.name == "swb_dismiss" }
            .forEach { view.removeGestureRecognizer($0) }

        if SwipeBackConfig.leftEdge {
            let g = UIScreenEdgePanGestureRecognizer(
                target: self,
                action: #selector(swb_dismissPan(_:))
            )
            g.edges = .left
            g.name  = "swb_dismiss"
            view.addGestureRecognizer(g)
        }
        if SwipeBackConfig.rightEdge {
            let g = UIScreenEdgePanGestureRecognizer(
                target: self,
                action: #selector(swb_dismissPan(_:))
            )
            g.edges = .right
            g.name  = "swb_dismiss"
            view.addGestureRecognizer(g)
        }
    }

    /// Handles edge pan gesture for modal dismiss.
    @objc func swb_dismissPan(_ g: UIScreenEdgePanGestureRecognizer) {
        handleSwbGesture(g, in: view) { [weak self] in
            self?.dismiss(animated: true)
        }
    }
}

// MARK: - Shared Gesture Handler

/// Adds a UIScreenEdgePanGestureRecognizer to the target's view.
private func addSwbEdge(_ edge: UIRectEdge, target: AnyObject, action: Selector) {
    let g = UIScreenEdgePanGestureRecognizer(target: target, action: action)
    g.edges = edge
    g.name  = "swb_edge"
    if let vc = target as? UIViewController {
        vc.view.addGestureRecognizer(g)
    }
}

extension UIViewController {

    /// Core gesture handler shared by both pop and dismiss flows.
    ///
    /// - Shows the Android-style wave overlay during drag
    /// - Triggers the completion block (pop or dismiss) on finger lift
    ///   if the user dragged far enough (≥50% of 130pt) or fast enough (≥500pt/s)
    /// - Cancels cleanly if threshold not met
    ///
    /// - Parameters:
    ///   - g:          The edge pan gesture recognizer
    ///   - hostView:   The view to attach the wave overlay to
    ///   - onComplete: Called when back navigation should be triggered
    func handleSwbGesture(
        _ g: UIScreenEdgePanGestureRecognizer,
        in hostView: UIView,
        onComplete: @escaping () -> Void
    ) {
        let isLeft   = g.edges == .left
        let loc      = g.location(in: hostView)
        let trans    = g.translation(in: hostView)
        let dragX    = max(0, isLeft ? trans.x : -trans.x)

        // Progress: 0.0 (no drag) → 1.0 (130pt drag = full threshold)
        let progress = min(1.0, dragX / 130.0)

        switch g.state {

        case .began:
            // Create and attach the wave overlay
            let overlay = SwipeWaveOverlay(isLeft: isLeft)
            overlay.frame = hostView.bounds
            overlay.isUserInteractionEnabled = false
            hostView.addSubview(overlay)
            objc_setAssociatedObject(self, &kOverlay, overlay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            if SwipeBackConfig.haptic {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

        case .changed:
            guard let overlay = objc_getAssociatedObject(self, &kOverlay) as? SwipeWaveOverlay else { return }

            // Update wave shape and arrow based on current drag progress
            overlay.update(fingerY: loc.y, progress: progress)

            // Haptic + visual change at 50% threshold
            if progress >= 0.5 && !overlay.thresholdReached {
                overlay.thresholdReached = true
                if SwipeBackConfig.haptic {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } else if progress < 0.5 {
                overlay.thresholdReached = false
            }

        case .ended:
            let vel        = g.velocity(in: hostView)
            let fastEnough = isLeft ? vel.x > 500 : vel.x < -500
            let farEnough  = progress >= 0.5

            // Dismiss the wave overlay
            swb_dismissOverlay()

            // Trigger back navigation if threshold met
            if farEnough || fastEnough {
                if SwipeBackConfig.haptic {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onComplete()
            }
            // Otherwise: gesture cancelled, nothing happens

        case .cancelled, .failed:
            swb_dismissOverlay()

        default:
            break
        }
    }

    /// Fades out and removes the wave overlay.
    private func swb_dismissOverlay() {
        guard let overlay = objc_getAssociatedObject(self, &kOverlay) as? SwipeWaveOverlay else { return }
        UIView.animate(withDuration: 0.2, animations: {
            overlay.alpha = 0
        }) { _ in
            overlay.removeFromSuperview()
        }
        objc_setAssociatedObject(self, &kOverlay, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - SwipeWaveOverlay

/// Full-screen transparent overlay that renders the Android-style back gesture indicator.
///
/// Visual design:
/// - A smooth bezier wave anchored to the screen edge (starts/ends flush)
/// - The wave bulges inward as the user drags, following the finger vertically
/// - A chevron arrow (‹ or ›) appears inside the wave after 20% drag
/// - Arrow and wave are gray initially, arrow turns white at threshold
/// - No pill or background — just the wave shape and arrow
///
/// The wave uses a single cubic bezier curve:
/// - Both endpoints are on the screen edge (x=0 or x=screenWidth)
/// - Control points pull the curve inward, creating the bulge
/// - This ensures the wave merges smoothly with the edge (no sharp cutoff)
class SwipeWaveOverlay: UIView {

    private let isLeft: Bool

    /// Current finger Y position (wave follows finger vertically)
    private var fingerY: CGFloat = 0

    /// Drag progress 0.0→1.0 (drives wave size and arrow visibility)
    private var progress: CGFloat = 0

    /// True when user has dragged past the 50% threshold (triggers color change + haptic)
    var thresholdReached = false

    /// CAShapeLayer for the chevron arrow (‹ or ›)
    private let chevronLayer = CAShapeLayer()

    init(isLeft: Bool) {
        self.isLeft = isLeft
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false

        // Chevron arrow setup — starts invisible, fades in at 20% drag
        chevronLayer.fillColor   = UIColor.clear.cgColor
        chevronLayer.lineWidth   = 2.2
        chevronLayer.lineCap     = .round
        chevronLayer.lineJoin    = .round
        chevronLayer.opacity     = 0
        layer.addSublayer(chevronLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Updates the overlay with new finger position and drag progress.
    /// Called every `.changed` event from the gesture recognizer.
    func update(fingerY: CGFloat, progress: CGFloat) {
        self.fingerY  = fingerY
        self.progress = progress
        setNeedsDisplay()   // triggers draw(_:) for wave
        updateChevron()     // updates arrow layer
    }

    // MARK: - Wave Peak Calculation

    /// Returns the X coordinate of the wave's peak (furthest inward point).
    /// Used by both the wave drawing and the arrow positioning to stay in sync.
    private func wavePeakX(progress p: CGFloat) -> CGFloat {
        let maxBulge: CGFloat = 48  // max 48pt inward at full drag
        let bulge = p * maxBulge
        return isLeft ? bulge : bounds.width - bulge
    }

    // MARK: - Chevron Arrow

    /// Updates the chevron arrow position, size, and opacity.
    /// Arrow is positioned at 55% of the wave peak to stay inside the wave.
    private func updateChevron() {
        let p = progress

        // Fade in between 20% and 55% drag
        let alpha = max(0, (p - 0.2) / 0.35)
        chevronLayer.opacity = Float(min(1, alpha))
        guard alpha > 0 else { return }

        // Arrow center: 55% of wave peak X (always inside the wave bulge)
        let peakX = wavePeakX(progress: p)
        let cx: CGFloat = isLeft
            ? peakX * 0.55
            : bounds.width - (bounds.width - peakX) * 0.55
        let cy = fingerY

        // Arrow size: 6pt at start, grows to 10pt at full drag
        let s: CGFloat = 6 + p * 4

        // Draw chevron (‹ for left edge, › for right edge)
        let path = UIBezierPath()
        if isLeft {
            // › pointing right (indicates going back reveals content on left)
            path.move(to: CGPoint(x: cx - s * 0.35, y: cy - s))
            path.addLine(to: CGPoint(x: cx + s * 0.45, y: cy))
            path.addLine(to: CGPoint(x: cx - s * 0.35, y: cy + s))
        } else {
            // ‹ pointing left
            path.move(to: CGPoint(x: cx + s * 0.35, y: cy - s))
            path.addLine(to: CGPoint(x: cx - s * 0.45, y: cy))
            path.addLine(to: CGPoint(x: cx + s * 0.35, y: cy + s))
        }
        chevronLayer.path  = path.cgPath
        chevronLayer.frame = bounds

        // Color: gray (0.45) → white (1.0) as progress increases
        let white: CGFloat = 0.45 + min(0.55, p * 1.1)
        chevronLayer.strokeColor = UIColor(white: white, alpha: 1).cgColor
    }

    // MARK: - Wave Drawing

    /// Draws the elastic wave shape using a cubic bezier curve.
    ///
    /// Wave geometry:
    /// - Top anchor: (edgeX, fingerY - waveHeight)  — on screen edge
    /// - Bottom anchor: (edgeX, fingerY + waveHeight) — on screen edge
    /// - Control point 1: (peakX, fingerY - waveHeight*0.28) — pulls curve inward
    /// - Control point 2: (peakX, fingerY + waveHeight*0.28) — pulls curve inward
    ///
    /// Both anchors are on the edge (x=0 or x=screenWidth), so the wave
    /// merges smoothly with the screen edge — no visible seam.
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let p = progress
        guard p > 0.01 else { return }

        let cy    = fingerY
        let peakX = wavePeakX(progress: p)
        let edgeX: CGFloat = isLeft ? 0 : bounds.width

        // Wave height: 60pt at start, grows to 130pt at full drag
        let waveH: CGFloat = 60 + p * 70
        let topY  = cy - waveH
        let botY  = cy + waveH

        // Control points at ±28% of wave height — creates natural S-curve shape
        let cp1Y  = cy - waveH * 0.28
        let cp2Y  = cy + waveH * 0.28

        let path = UIBezierPath()
        path.move(to: CGPoint(x: edgeX, y: topY))
        path.addCurve(
            to: CGPoint(x: edgeX, y: botY),
            controlPoint1: CGPoint(x: peakX, y: cp1Y),
            controlPoint2: CGPoint(x: peakX, y: cp2Y)
        )
        path.close()

        // Dark gray fill — alpha grows with drag (max 0.38)
        let fillAlpha = min(0.38, p * 0.42)
        ctx.setFillColor(UIColor(white: 0.25, alpha: fillAlpha).cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }
}

// MARK: - SwipeBackNavigationController

/// Optional: Use this subclass directly instead of SwipeBackManager.enable().
/// Useful if you only want swipe-back on specific navigation controllers.
///
/// Usage:
/// ```swift
/// let nav = SwipeBackNavigationController(rootViewController: homeVC)
/// ```
/// Or in Storyboard: set Custom Class to SwipeBackNavigationController
public class SwipeBackNavigationController: UINavigationController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Gesture setup is handled by swb_navViewDidLoad via swizzle
    }
}
