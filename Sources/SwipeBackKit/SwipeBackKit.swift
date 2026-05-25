import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

// ─────────────────────────────────────────────────────────────────────────────
// SwipeBackKit v1.1.0
// Android-style edge swipe navigation for iOS
//
// New in v1.1.0:
//   • Disable per-screen: SwipeBackKit.disable(for: self)
//   • SwiftUI support: .swipeBackEnabled() modifier
//   • Spring-back animation when gesture is cancelled
//   • Double-swipe to exit on root screen (with Android-style toast)
//
// Usage:
//   SwipeBackManager.enable()   // in AppDelegate.didFinishLaunching
// ─────────────────────────────────────────────────────────────────────────────

// MARK: - SwipeBackManager

/// The primary class for integrating SwipeBackKit with your app.
///
/// SwipeBackKit brings Android 10+ style back gesture to iOS — swipe from
/// either edge of the screen to navigate back, with an elastic wave animation
/// and haptic feedback.
///
/// **Quick start:**
/// ```swift
/// // AppDelegate.swift
/// func application(_ application: UIApplication,
///                  didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
///     SwipeBackManager.enable()
///     return true
/// }
/// ```
///
/// **With options:**
/// ```swift
/// SwipeBackManager.enable(
///     leftEdge:        true,   // left edge → back
///     rightEdge:       true,   // right edge → back (Android 10+ style)
///     haptic:          true,   // haptic feedback at threshold
///     exitOnRootSwipe: true    // double-swipe to exit on root screen
/// )
/// ```
public class SwipeBackManager {

    /// Enables Android-style swipe-back for the entire app.
    ///
    /// Call this once in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    /// All `UINavigationController` instances and modally presented view controllers
    /// in the app will automatically receive swipe-back support — no subclassing required.
    ///
    /// - parameter leftEdge:        Whether to enable swipe from the left edge of the screen.
    ///                              This is the standard iOS back direction. Defaults to `true`.
    /// - parameter rightEdge:       Whether to enable swipe from the right edge of the screen.
    ///                              This mirrors Android 10+ behavior. Defaults to `true`.
    /// - parameter haptic:          Whether to trigger haptic feedback when the gesture begins
    ///                              and when the back threshold is reached. Defaults to `true`.
    /// - parameter exitOnRootSwipe: Whether to show a "Swipe again to exit" toast when the user
    ///                              swipes on the root (first) screen. A second swipe within 2
    ///                              seconds moves the app to the background. Defaults to `true`.
    ///
    /// **Example — Default (all features enabled):**
    /// ```swift
    /// SwipeBackManager.enable()
    /// ```
    ///
    /// **Example — Disable right edge and exit behavior:**
    /// ```swift
    /// SwipeBackManager.enable(rightEdge: false, exitOnRootSwipe: false)
    /// ```
    public static func enable(
        leftEdge:        Bool = true,
        rightEdge:       Bool = true,
        haptic:          Bool = true,
        exitOnRootSwipe: Bool = true
    ) {
        SwipeBackConfig.leftEdge        = leftEdge
        SwipeBackConfig.rightEdge       = rightEdge
        SwipeBackConfig.haptic          = haptic
        SwipeBackConfig.exitOnRootSwipe = exitOnRootSwipe
        SwipeBackConfig.swizzleNavController()
        SwipeBackConfig.swizzleViewController()
    }

    /// Disables the swipe-back gesture for a specific view controller.
    ///
    /// Use this on screens where the edge swipe would conflict with your UI —
    /// for example, a drawing canvas, a map, or a carousel.
    /// The gesture is automatically re-enabled when the view controller is deallocated.
    ///
    /// - parameter viewController: The view controller on which to disable swipe-back.
    ///
    /// **Example:**
    /// ```swift
    /// override func viewDidLoad() {
    ///     super.viewDidLoad()
    ///     SwipeBackManager.disable(for: self)
    /// }
    /// ```
    ///
    /// **SwiftUI equivalent:**
    /// ```swift
    /// MyView()
    ///     .swipeBackDisabled()
    /// ```
    public static func disable(for viewController: UIViewController) {
        objc_setAssociatedObject(
            viewController,
            &SwipeBackConfig.kDisabled,
            true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// Re-enables the swipe-back gesture for a specific view controller.
    ///
    /// Only needed if you previously called `disable(for:)` and want to
    /// re-enable the gesture dynamically (e.g. after a loading state completes).
    ///
    /// - parameter viewController: The view controller on which to re-enable swipe-back.
    public static func enable(for viewController: UIViewController) {
        objc_setAssociatedObject(
            viewController,
            &SwipeBackConfig.kDisabled,
            false,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// Returns whether swipe-back is currently disabled for the given view controller.
    ///
    /// - parameter viewController: The view controller to check.
    /// - returns: `true` if swipe-back has been disabled via `disable(for:)`, `false` otherwise.
    public static func isDisabled(for viewController: UIViewController) -> Bool {
        return objc_getAssociatedObject(viewController, &SwipeBackConfig.kDisabled) as? Bool ?? false
    }
}

// MARK: - SwiftUI Support

#if canImport(SwiftUI)
/// A SwiftUI `ViewModifier` that disables the SwipeBackKit edge gesture on the modified view.
///
/// Apply this modifier using the `.swipeBackDisabled()` convenience extension on `View`.
///
/// **Example:**
/// ```swift
/// struct DrawingCanvasView: View {
///     var body: some View {
///         Canvas { ... }
///             .swipeBackDisabled()  // edge swipe would conflict with drawing
///     }
/// }
/// ```
@available(iOS 14.0, *)
public struct SwipeBackDisabledModifier: ViewModifier {
    /// Applies the modifier by injecting a hidden `UIViewController` that disables
    /// the swipe gesture when it appears and re-enables it when it disappears.
    public func body(content: Content) -> some View {
        content
            .background(SwipeBackDisabledRepresentable())
    }
}

@available(iOS 14.0, *)
struct SwipeBackDisabledRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackDisablerVC {
        SwipeBackDisablerVC()
    }
    func updateUIViewController(_ uiViewController: SwipeBackDisablerVC, context: Context) {}
}

@available(iOS 14.0, *)
class SwipeBackDisablerVC: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SwipeBackManager.disable(for: self)
        // Also disable on parent if embedded
        if let parent = parent {
            SwipeBackManager.disable(for: parent)
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        SwipeBackManager.enable(for: self)
        if let parent = parent {
            SwipeBackManager.enable(for: parent)
        }
    }
}

@available(iOS 14.0, *)
extension View {
    /// Disables the SwipeBackKit edge swipe gesture on this SwiftUI view.
    ///
    /// Use this on views where an edge swipe would conflict with your UI,
    /// such as drawing canvases, maps, carousels, or custom gesture-heavy screens.
    ///
    /// - returns: A view with the SwipeBackKit gesture disabled.
    ///
    /// **Example:**
    /// ```swift
    /// MapView()
    ///     .swipeBackDisabled()
    /// ```
    public func swipeBackDisabled() -> some View {
        modifier(SwipeBackDisabledModifier())
    }

    /// Explicitly marks this SwiftUI view as swipe-back enabled.
    ///
    /// This is the default behavior — calling this method is a no-op and exists
    /// only for documentation clarity in code that conditionally enables/disables.
    ///
    /// - returns: The unmodified view.
    public func swipeBackEnabled() -> some View {
        self
    }
}
#endif

// MARK: - Internal Configuration

private class SwipeBackConfig {
    static var leftEdge:        Bool = true
    static var rightEdge:       Bool = true
    static var haptic:          Bool = true
    static var exitOnRootSwipe: Bool = true

    // Associated object keys
    static var kDisabled: UInt8 = 0

    static func swizzleNavController() {
        let orig = class_getInstanceMethod(UINavigationController.self, #selector(UINavigationController.viewDidLoad))
        let swiz = class_getInstanceMethod(UINavigationController.self, #selector(UINavigationController.swb_navViewDidLoad))
        if let o = orig, let s = swiz { method_exchangeImplementations(o, s) }
    }

    static func swizzleViewController() {
        let orig = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidAppear(_:)))
        let swiz = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.swb_viewDidAppear(_:)))
        if let o = orig, let s = swiz { method_exchangeImplementations(o, s) }
    }
}

// MARK: - Associated Object Keys

private var kOverlay:   UInt8 = 0
private var kExitTimer: UInt8 = 0

// MARK: - UINavigationController Extension (Push/Pop)

extension UINavigationController {

    @objc func swb_navViewDidLoad() {
        swb_navViewDidLoad()
        interactivePopGestureRecognizer?.isEnabled = false
        if SwipeBackConfig.leftEdge  {
            let g = makeSwbEdgeGesture(.left, target: self, action: #selector(swb_navPan(_:)))
            view.addGestureRecognizer(g)
        }
        if SwipeBackConfig.rightEdge {
            let g = makeSwbEdgeGesture(.right, target: self, action: #selector(swb_navPan(_:)))
            view.addGestureRecognizer(g)
        }
    }

    @objc func swb_navPan(_ g: UIScreenEdgePanGestureRecognizer) {
        // Don't fire if a sheet/modal is currently presented on top
        if presentedViewController != nil { return }
        // Check if top VC has swipe disabled
        if let topVC = topViewController, SwipeBackManager.isDisabled(for: topVC) { return }

        if viewControllers.count > 1 {
            handleSwbGesture(g, in: view) { [weak self] in
                self?.popViewController(animated: true)
            }
        } else if SwipeBackConfig.exitOnRootSwipe {
            handleRootSwipe(g)
        }
    }

    /// Handles swipe on root screen — shows toast, exits on second swipe.
    private func handleRootSwipe(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended else { return }

        let isLeft = g.edges == .left
        let trans  = g.translation(in: view)
        let dragX  = max(0, isLeft ? trans.x : -trans.x)
        let vel    = g.velocity(in: view)
        let fastEnough = isLeft ? vel.x > 500 : vel.x < -500
        guard dragX > 60 || fastEnough else { return }

        let now = Date()
        let lastSwipe = objc_getAssociatedObject(self, &kExitTimer) as? Date

        if let last = lastSwipe, now.timeIntervalSince(last) < 2.0 {
            // Second swipe within 2 seconds — move to background
            objc_setAssociatedObject(self, &kExitTimer, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        } else {
            // First swipe — show toast
            objc_setAssociatedObject(self, &kExitTimer, now, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            showExitToast(in: view)
            if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }

    /// Shows Android-style "Swipe again to exit" toast from top of screen.
    private func showExitToast(in hostView: UIView) {
        let toast = SwipeExitToast()
        toast.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            toast.topAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.topAnchor, constant: 12),
            toast.widthAnchor.constraint(lessThanOrEqualTo: hostView.widthAnchor, multiplier: 0.85)
        ])

        // Animate in from top
        toast.transform = CGAffineTransform(translationX: 0, y: -80)
        toast.alpha = 0
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            toast.transform = .identity
            toast.alpha = 1
        }

        // Auto dismiss after 2 seconds
        UIView.animate(withDuration: 0.3, delay: 2.0) {
            toast.alpha = 0
            toast.transform = CGAffineTransform(translationX: 0, y: -40)
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

// MARK: - UIViewController Extension (Present/Dismiss)

extension UIViewController {

    @objc func swb_viewDidAppear(_ animated: Bool) {
        swb_viewDidAppear(animated)

        // Skip if disabled for this VC
        guard !SwipeBackManager.isDisabled(for: self) else { return }

        guard presentingViewController != nil,
              !(self is UINavigationController),
              !(self is UITabBarController),
              navigationController == nil
        else { return }

        view.gestureRecognizers?
            .filter { $0.name == "swb_dismiss" }
            .forEach { view.removeGestureRecognizer($0) }

        if SwipeBackConfig.leftEdge {
            let g = makeSwbEdgeGesture(.left, target: self, action: #selector(swb_dismissPan(_:)))
            g.name = "swb_dismiss"
            view.addGestureRecognizer(g)
        }
        if SwipeBackConfig.rightEdge {
            let g = makeSwbEdgeGesture(.right, target: self, action: #selector(swb_dismissPan(_:)))
            g.name = "swb_dismiss"
            view.addGestureRecognizer(g)
        }
    }

    @objc func swb_dismissPan(_ g: UIScreenEdgePanGestureRecognizer) {
        guard !SwipeBackManager.isDisabled(for: self) else { return }
        handleSwbGesture(g, in: view) { [weak self] in
            self?.dismiss(animated: true)
        }
    }
}

// MARK: - Shared Gesture Handler

/// Creates a configured `UIScreenEdgePanGestureRecognizer` with delegate support
/// for resolving conflicts with `UIScrollView` and other gesture recognizers.
private func makeSwbEdgeGesture(_ edge: UIRectEdge, target: AnyObject, action: Selector) -> UIScreenEdgePanGestureRecognizer {
    let g = SwbEdgeGestureRecognizer(target: target, action: action)
    g.edges = edge
    g.name  = "swb_edge"
    return g
}

private func addSwbEdge(_ edge: UIRectEdge, target: AnyObject, action: Selector) {
    let g = makeSwbEdgeGesture(edge, target: target, action: action)
    if let vc = target as? UIViewController { vc.view.addGestureRecognizer(g) }
}

/// Custom subclass of UIScreenEdgePanGestureRecognizer that resolves conflicts
/// with UIScrollView and other pan gestures.
private class SwbEdgeGestureRecognizer: UIScreenEdgePanGestureRecognizer, UIGestureRecognizerDelegate {

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
    }

    /// Allow simultaneous recognition with scroll views.
    /// The edge gesture will win because UIScreenEdgePanGestureRecognizer
    /// has higher priority at the screen edge.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // Allow with scroll views — edge gesture takes priority at the edge
        return other is UIPanGestureRecognizer
    }

    /// Require scroll views to fail before our gesture begins,
    /// but only when the scroll view is at its leftmost/rightmost position.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        // If the other gesture is a scroll view's pan, check if scroll is at edge
        if let pan = other as? UIPanGestureRecognizer,
           let scrollView = pan.view as? UIScrollView {
            let isLeftEdge = edges == .left
            let atEdge = isLeftEdge
                ? scrollView.contentOffset.x <= 0
                : scrollView.contentOffset.x >= scrollView.contentSize.width - scrollView.bounds.width
            return atEdge
        }
        return false
    }
}

extension UIViewController {

    func handleSwbGesture(
        _ g: UIScreenEdgePanGestureRecognizer,
        in hostView: UIView,
        onComplete: @escaping () -> Void
    ) {
        let isLeft   = g.edges == .left
        let loc      = g.location(in: hostView)
        let trans    = g.translation(in: hostView)
        let dragX    = max(0, isLeft ? trans.x : -trans.x)
        let progress = min(1.0, dragX / 130.0)

        switch g.state {

        case .began:
            let overlay = SwipeWaveOverlay(isLeft: isLeft)
            overlay.frame = hostView.bounds
            overlay.isUserInteractionEnabled = false
            hostView.addSubview(overlay)
            objc_setAssociatedObject(self, &kOverlay, overlay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

        case .changed:
            guard let overlay = objc_getAssociatedObject(self, &kOverlay) as? SwipeWaveOverlay else { return }
            overlay.update(fingerY: loc.y, progress: progress)
            if progress >= 0.5 && !overlay.thresholdReached {
                overlay.thresholdReached = true
                if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            } else if progress < 0.5 {
                overlay.thresholdReached = false
            }

        case .ended:
            let vel        = g.velocity(in: hostView)
            let fastEnough = isLeft ? vel.x > 500 : vel.x < -500
            let farEnough  = progress >= 0.5

            if farEnough || fastEnough {
                // Complete — dismiss overlay then navigate
                swb_dismissOverlay(springBack: false)
                if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                onComplete()
            } else {
                // Cancelled — spring back animation
                swb_dismissOverlay(springBack: true)
            }

        case .cancelled, .failed:
            swb_dismissOverlay(springBack: true)

        default: break
        }
    }

    /// Dismisses the wave overlay.
    /// - Parameter springBack: If true, animates the wave springing back to the edge before fading.
    private func swb_dismissOverlay(springBack: Bool) {
        guard let overlay = objc_getAssociatedObject(self, &kOverlay) as? SwipeWaveOverlay else { return }

        if springBack {
            // Spring back: wave contracts back to edge, then fades
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.8,
                options: [.curveEaseOut]
            ) {
                overlay.springBack()
            } completion: { _ in
                UIView.animate(withDuration: 0.15) {
                    overlay.alpha = 0
                } completion: { _ in
                    overlay.removeFromSuperview()
                }
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: { overlay.alpha = 0 }) { _ in
                overlay.removeFromSuperview()
            }
        }

        objc_setAssociatedObject(self, &kOverlay, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - SwipeWaveOverlay

/// A full-screen transparent overlay that renders the Android-style back gesture indicator.
///
/// This view is added to the host view when a swipe gesture begins and removed when it ends.
/// It draws two visual elements:
///
/// 1. **Wave shape** — a smooth cubic bezier curve anchored to the screen edge.
///    Both endpoints sit on the edge (x=0 or x=screenWidth), so the wave merges
///    flush with the screen — no visible seam. The wave bulges inward as the user drags.
///
/// 2. **Chevron arrow** — a `‹` or `›` symbol that fades in after 20% drag and
///    grows slightly as the user continues. The arrow is always positioned inside
///    the wave bulge area.
///
/// When the gesture is cancelled, `springBack()` animates the wave back to the edge
/// before the view fades out, giving a satisfying elastic feel.
class SwipeWaveOverlay: UIView {

    /// Whether the gesture is from the left edge (`true`) or right edge (`false`).
    private let isLeft: Bool

    /// The current Y position of the user's finger. The wave follows this vertically.
    private var fingerY: CGFloat = 0

    /// Drag progress from `0.0` (no drag) to `1.0` (full threshold reached).
    /// Drives wave size, arrow opacity, and arrow size.
    private var progress: CGFloat = 0

    /// Set to `true` when the user has dragged past the 50% threshold.
    /// Triggers a haptic feedback pulse and is used to track state changes.
    var thresholdReached = false

    /// The CAShapeLayer that renders the chevron arrow (`‹` or `›`).
    private let chevronLayer = CAShapeLayer()

    init(isLeft: Bool) {
        self.isLeft = isLeft
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        chevronLayer.fillColor   = UIColor.clear.cgColor
        chevronLayer.lineWidth   = 2.2
        chevronLayer.lineCap     = .round
        chevronLayer.lineJoin    = .round
        chevronLayer.opacity     = 0
        layer.addSublayer(chevronLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Updates the overlay with the current finger position and drag progress.
    ///
    /// Called on every `.changed` event from the gesture recognizer.
    /// Triggers a redraw of the wave shape and updates the chevron arrow.
    ///
    /// - parameter fingerY:  The current Y position of the user's finger in the host view's coordinate space.
    /// - parameter progress: The drag progress from `0.0` (no drag) to `1.0` (full threshold).
    func update(fingerY: CGFloat, progress: CGFloat) {
        self.fingerY  = fingerY
        self.progress = progress
        setNeedsDisplay()
        updateChevron()
    }

    /// Resets the wave to zero progress, creating a spring-back visual effect.
    ///
    /// Called when the gesture is cancelled or the user releases without reaching the threshold.
    /// Should be called inside a `UIView.animate` block for the spring animation.
    func springBack() {
        progress = 0
        setNeedsDisplay()
        chevronLayer.opacity = 0
    }

    private func wavePeakX(progress p: CGFloat) -> CGFloat {
        let bulge = p * 48
        return isLeft ? bulge : bounds.width - bulge
    }

    private func updateChevron() {
        let p = progress
        let alpha = max(0, (p - 0.2) / 0.35)
        chevronLayer.opacity = Float(min(1, alpha))
        guard alpha > 0 else { return }

        let peakX = wavePeakX(progress: p)
        let cx: CGFloat = isLeft ? peakX * 0.55 : bounds.width - (bounds.width - peakX) * 0.55
        let cy = fingerY
        let s: CGFloat = 6 + p * 4

        let path = UIBezierPath()
        if isLeft {
            path.move(to: CGPoint(x: cx - s * 0.35, y: cy - s))
            path.addLine(to: CGPoint(x: cx + s * 0.45, y: cy))
            path.addLine(to: CGPoint(x: cx - s * 0.35, y: cy + s))
        } else {
            path.move(to: CGPoint(x: cx + s * 0.35, y: cy - s))
            path.addLine(to: CGPoint(x: cx - s * 0.45, y: cy))
            path.addLine(to: CGPoint(x: cx + s * 0.35, y: cy + s))
        }
        chevronLayer.path  = path.cgPath
        chevronLayer.frame = bounds
        let white: CGFloat = 0.45 + min(0.55, p * 1.1)
        chevronLayer.strokeColor = UIColor(white: white, alpha: 1).cgColor
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let p = progress
        guard p > 0.01 else { return }

        let cy    = fingerY
        let peakX = wavePeakX(progress: p)
        let edgeX: CGFloat = isLeft ? 0 : bounds.width
        let waveH: CGFloat = 60 + p * 70
        let topY  = cy - waveH
        let botY  = cy + waveH
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

        let fillAlpha = min(0.38, p * 0.42)
        ctx.setFillColor(UIColor(white: 0.25, alpha: fillAlpha).cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }
}

// MARK: - SwipeExitToast

/// An Android-style toast notification that slides in from the top of the screen.
///
/// Displayed when the user swipes on the root (first) view controller, informing them
/// that a second swipe within 2 seconds will move the app to the background.
///
/// The toast uses a frosted glass (`UIBlurEffect`) background and auto-dismisses
/// after 2 seconds with a slide-up fade animation.
///
/// This view is created and managed internally by `SwipeBackKit`.
/// You do not need to instantiate it directly.
class SwipeExitToast: UIView {

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Frosted glass background
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 22
        blur.clipsToBounds = true
        addSubview(blur)

        // Label
        let label = UILabel()
        label.text = "Swipe again to exit"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -12),
        ])
    }
}

// MARK: - SwipeBackNavigationController

/// An optional `UINavigationController` subclass that provides SwipeBackKit support.
///
/// Use this subclass if you prefer explicit opt-in over the global swizzle approach,
/// or if you only want swipe-back on specific navigation controllers in your app.
///
/// For app-wide support, prefer `SwipeBackManager.enable()` in your AppDelegate instead.
///
/// **Usage — programmatic:**
/// ```swift
/// let nav = SwipeBackNavigationController(rootViewController: homeVC)
/// window?.rootViewController = nav
/// ```
///
/// **Usage — Storyboard:**
/// Select your `UINavigationController` → Identity Inspector → Custom Class → `SwipeBackNavigationController`
public class SwipeBackNavigationController: UINavigationController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Gesture setup is handled automatically by swb_navViewDidLoad via method swizzling.
        // No additional configuration needed here.
    }
}
