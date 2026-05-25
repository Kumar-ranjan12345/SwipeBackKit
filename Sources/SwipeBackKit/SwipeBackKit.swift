import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

// ─────────────────────────────────────────────────────────────────────────────
// SwipeBackKit v1.3.0
// Android-style edge swipe navigation for iOS
//
// New in v1.3.0:
//   • Predictive back — slow drag reveals previous screen live (interactive)
//   • Fast flick → instant pop (same as before)
//   • Parallax slide transition (previous VC at 30% speed, current at 100%)
//   • UIPercentDrivenInteractiveTransition drives real VC transition
//   • Wave overlay still plays during interactive transition
//
// Usage:
//   SwipeBackManager.enable()   // in AppDelegate.didFinishLaunching
// ─────────────────────────────────────────────────────────────────────────────

// MARK: - SwipeBackManager

/// The primary class for integrating SwipeBackKit with your app.
///
/// SwipeBackKit brings Android 10+ style back gesture to iOS — swipe from
/// either edge of the screen to navigate back, with an elastic wave animation,
/// haptic feedback, and a fully interactive predictive transition.
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
///     leftEdge:        true,
///     rightEdge:       true,
///     haptic:          true,
///     exitOnRootSwipe: true
/// )
/// ```
public class SwipeBackManager {

    /// Enables Android-style swipe-back for the entire app.
    ///
    /// Call this once in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// - parameter leftEdge:        Enable swipe from left edge. Defaults to `true`.
    /// - parameter rightEdge:       Enable swipe from right edge. Defaults to `true`.
    /// - parameter haptic:          Haptic feedback at threshold. Defaults to `true`.
    /// - parameter exitOnRootSwipe: Double-swipe to exit on root screen. Defaults to `true`.
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
    /// - parameter viewController: The view controller on which to disable swipe-back.
    public static func disable(for viewController: UIViewController) {
        objc_setAssociatedObject(
            viewController, &SwipeBackConfig.kDisabled,
            true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// Re-enables the swipe-back gesture for a specific view controller.
    ///
    /// - parameter viewController: The view controller on which to re-enable swipe-back.
    public static func enable(for viewController: UIViewController) {
        objc_setAssociatedObject(
            viewController, &SwipeBackConfig.kDisabled,
            false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// Returns whether swipe-back is currently disabled for the given view controller.
    ///
    /// - parameter viewController: The view controller to check.
    /// - returns: `true` if disabled, `false` otherwise.
    public static func isDisabled(for viewController: UIViewController) -> Bool {
        return objc_getAssociatedObject(viewController, &SwipeBackConfig.kDisabled) as? Bool ?? false
    }
}

// MARK: - SwiftUI Support

#if canImport(SwiftUI)
/// A SwiftUI `ViewModifier` that disables the SwipeBackKit edge gesture on the modified view.
@available(iOS 14.0, *)
public struct SwipeBackDisabledModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content.background(SwipeBackDisabledRepresentable())
    }
}

@available(iOS 14.0, *)
struct SwipeBackDisabledRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackDisablerVC { SwipeBackDisablerVC() }
    func updateUIViewController(_ uiViewController: SwipeBackDisablerVC, context: Context) {}
}

@available(iOS 14.0, *)
class SwipeBackDisablerVC: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SwipeBackManager.disable(for: self)
        if let parent = parent { SwipeBackManager.disable(for: parent) }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        SwipeBackManager.enable(for: self)
        if let parent = parent { SwipeBackManager.enable(for: parent) }
    }
}

@available(iOS 14.0, *)
extension View {
    /// Disables the SwipeBackKit edge swipe gesture on this SwiftUI view.
    public func swipeBackDisabled() -> some View { modifier(SwipeBackDisabledModifier()) }

    /// Explicitly marks this SwiftUI view as swipe-back enabled (no-op, for clarity).
    public func swipeBackEnabled() -> some View { self }
}
#endif

// MARK: - Internal Configuration

private class SwipeBackConfig {
    static var leftEdge:        Bool = true
    static var rightEdge:       Bool = true
    static var haptic:          Bool = true
    static var exitOnRootSwipe: Bool = true

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

private var kOverlay:      UInt8 = 0
private var kExitTimer:    UInt8 = 0
private var kInteraction:  UInt8 = 0
private var kNavDelegate:  UInt8 = 0

// MARK: - SwbInteractiveTransition

/// Drives the real UIKit navigation transition interactively with finger movement.
/// Slow drag → previous screen revealed live. Fast flick → instant finish.
final class SwbInteractiveTransition: UIPercentDrivenInteractiveTransition {
    /// Whether an interactive session is currently in progress.
    var isInteracting = false

    override var completionSpeed: CGFloat { return 0.85 }
}

// MARK: - SwbSlideTransition (Animated Transitioning)

/// Custom slide transition with parallax effect.
/// Previous VC slides in at 30% speed; current VC slides out at 100%.
/// This is what UIPercentDrivenInteractiveTransition drives during the gesture.
final class SwbSlideTransition: NSObject, UIViewControllerAnimatedTransitioning {

    let isLeft: Bool   // gesture came from left edge → pop goes right

    init(isLeft: Bool) { self.isLeft = isLeft }

    func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.38
    }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard
            let fromVC = ctx.viewController(forKey: .from),
            let toVC   = ctx.viewController(forKey: .to)
        else { ctx.completeTransition(false); return }

        let container  = ctx.containerView
        let width      = container.bounds.width

        // Direction: left-edge swipe → current slides RIGHT, previous comes from LEFT
        let outX: CGFloat  = isLeft ?  width : -width   // current VC exits to
        let inStartX: CGFloat = isLeft ? -width * 0.30 : width * 0.30  // previous VC starts at

        // Insert previous VC behind current
        container.insertSubview(toVC.view, belowSubview: fromVC.view)
        toVC.view.frame = ctx.finalFrame(for: toVC)
        toVC.view.transform = CGAffineTransform(translationX: inStartX, y: 0)

        // Add a dim overlay on the previous VC (starts at 0.18, goes to 0)
        let dimView = UIView(frame: toVC.view.bounds)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        toVC.view.addSubview(dimView)

        UIView.animate(
            withDuration: transitionDuration(using: ctx),
            delay: 0,
            options: [.curveEaseOut]
        ) {
            fromVC.view.transform = CGAffineTransform(translationX: outX, y: 0)
            toVC.view.transform   = .identity
            dimView.alpha         = 0
        } completion: { finished in
            fromVC.view.transform = .identity
            toVC.view.transform   = .identity
            dimView.removeFromSuperview()
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}

// MARK: - SwbNavDelegate

/// UINavigationControllerDelegate that provides the custom animated + interactive transition.
final class SwbNavDelegate: NSObject, UINavigationControllerDelegate {

    weak var originalDelegate: UINavigationControllerDelegate?
    var interactiveTransition: SwbInteractiveTransition?
    var isLeft: Bool = true

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        // Only intercept pop operations triggered by our gesture
        guard operation == .pop, interactiveTransition?.isInteracting == true else { return nil }
        return SwbSlideTransition(isLeft: isLeft)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        guard let it = interactiveTransition, it.isInteracting else { return nil }
        return it
    }

    // Forward any other delegate calls to the original delegate
    override func responds(to aSelector: Selector!) -> Bool {
        return super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if originalDelegate?.responds(to: aSelector) == true { return originalDelegate }
        return super.forwardingTarget(for: aSelector)
    }
}

// MARK: - UINavigationController Extension (Push/Pop)

extension UINavigationController {

    @objc func swb_navViewDidLoad() {
        swb_navViewDidLoad()
        interactivePopGestureRecognizer?.isEnabled = false

        // Install our SwbNavDelegate, preserving any existing delegate
        let swbDelegate = SwbNavDelegate()
        swbDelegate.originalDelegate = self.delegate
        self.delegate = swbDelegate
        // Retain it via associated object (delegate is weak in UIKit)
        objc_setAssociatedObject(self, &kNavDelegate, swbDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        if SwipeBackConfig.leftEdge {
            let g = makeSwbEdgeGesture(.left, target: self, action: #selector(swb_navPan(_:)))
            view.addGestureRecognizer(g)
        }
        if SwipeBackConfig.rightEdge {
            let g = makeSwbEdgeGesture(.right, target: self, action: #selector(swb_navPan(_:)))
            view.addGestureRecognizer(g)
        }
    }

    @objc func swb_navPan(_ g: UIScreenEdgePanGestureRecognizer) {
        if presentedViewController != nil { return }
        if let topVC = topViewController, SwipeBackManager.isDisabled(for: topVC) { return }

        if viewControllers.count > 1 {
            handleSwbNavGesture(g)
        } else if SwipeBackConfig.exitOnRootSwipe {
            handleRootSwipe(g)
        }
    }

    /// Core handler for nav pop with interactive transition.
    func handleSwbNavGesture(_ g: UIScreenEdgePanGestureRecognizer) {
        let isLeft   = g.edges == .left
        let trans    = g.translation(in: view)
        let dragX    = max(0, isLeft ? trans.x : -trans.x)
        let progress = min(1.0, dragX / view.bounds.width)
        let loc      = g.location(in: view)

        // Retrieve or create the SwbNavDelegate
        guard let swbDelegate = objc_getAssociatedObject(self, &kNavDelegate) as? SwbNavDelegate else { return }

        switch g.state {

        case .began:
            // Fast flick detection — if velocity is already high, skip interactive mode
            let vel = g.velocity(in: view)
            let isFastFlick = isLeft ? vel.x > 900 : vel.x < -900

            if isFastFlick {
                // Non-interactive instant pop with wave
                let overlay = SwipeWaveOverlay(isLeft: isLeft)
                overlay.frame = view.bounds
                overlay.isUserInteractionEnabled = false
                view.addSubview(overlay)
                objc_setAssociatedObject(self, &kOverlay, overlay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                overlay.update(fingerY: loc.y, progress: 0.8)
                if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                swb_dismissOverlay(springBack: false)
                popViewController(animated: true)
            } else {
                // Interactive mode — start transition immediately
                let it = SwbInteractiveTransition()
                it.isInteracting = true
                swbDelegate.interactiveTransition = it
                swbDelegate.isLeft = isLeft
                objc_setAssociatedObject(self, &kInteraction, it, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                // Wave overlay
                let overlay = SwipeWaveOverlay(isLeft: isLeft)
                overlay.frame = view.bounds
                overlay.isUserInteractionEnabled = false
                // We add overlay AFTER popViewController so it sits on top of the transition
                if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

                // This triggers the delegate → animationController + interactionController
                popViewController(animated: true)

                // Now add overlay on top
                view.addSubview(overlay)
                objc_setAssociatedObject(self, &kOverlay, overlay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }

        case .changed:
            guard let it = objc_getAssociatedObject(self, &kInteraction) as? SwbInteractiveTransition,
                  it.isInteracting else { return }
            it.update(progress)

            if let overlay = objc_getAssociatedObject(self, &kOverlay) as? SwipeWaveOverlay {
                overlay.update(fingerY: loc.y, progress: progress)
                if progress >= 0.5 && !overlay.thresholdReached {
                    overlay.thresholdReached = true
                    if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                } else if progress < 0.5 {
                    overlay.thresholdReached = false
                }
            }

        case .ended:
            guard let it = objc_getAssociatedObject(self, &kInteraction) as? SwbInteractiveTransition,
                  it.isInteracting else { return }

            let vel        = g.velocity(in: view)
            let fastEnough = isLeft ? vel.x > 400 : vel.x < -400
            let farEnough  = progress >= 0.45

            it.isInteracting = false
            swbDelegate.interactiveTransition = nil
            objc_setAssociatedObject(self, &kInteraction, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            if farEnough || fastEnough {
                swb_dismissOverlay(springBack: false)
                if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                it.finish()
            } else {
                swb_dismissOverlay(springBack: true)
                it.cancel()
            }

        case .cancelled, .failed:
            if let it = objc_getAssociatedObject(self, &kInteraction) as? SwbInteractiveTransition {
                it.isInteracting = false
                it.cancel()
                objc_setAssociatedObject(self, &kInteraction, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            swbDelegate.interactiveTransition = nil
            swb_dismissOverlay(springBack: true)

        default: break
        }
    }

    /// Handles swipe on root screen — shows toast, exits on second swipe.
    private func handleRootSwipe(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended else { return }
        let isLeft     = g.edges == .left
        let trans      = g.translation(in: view)
        let dragX      = max(0, isLeft ? trans.x : -trans.x)
        let vel        = g.velocity(in: view)
        let fastEnough = isLeft ? vel.x > 500 : vel.x < -500
        guard dragX > 60 || fastEnough else { return }

        let now       = Date()
        let lastSwipe = objc_getAssociatedObject(self, &kExitTimer) as? Date

        if let last = lastSwipe, now.timeIntervalSince(last) < 2.0 {
            objc_setAssociatedObject(self, &kExitTimer, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        } else {
            objc_setAssociatedObject(self, &kExitTimer, now, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            showExitToast(in: view)
            if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }

    private func showExitToast(in hostView: UIView) {
        let toast = SwipeExitToast()
        toast.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            toast.topAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.topAnchor, constant: 12),
            toast.widthAnchor.constraint(lessThanOrEqualTo: hostView.widthAnchor, multiplier: 0.85)
        ])
        toast.transform = CGAffineTransform(translationX: 0, y: -80)
        toast.alpha = 0
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            toast.transform = .identity; toast.alpha = 1
        }
        UIView.animate(withDuration: 0.3, delay: 2.0) {
            toast.alpha = 0; toast.transform = CGAffineTransform(translationX: 0, y: -40)
        } completion: { _ in toast.removeFromSuperview() }
    }
}

// MARK: - UIViewController Extension (Present/Dismiss)

extension UIViewController {

    @objc func swb_viewDidAppear(_ animated: Bool) {
        swb_viewDidAppear(animated)
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
        // Present/dismiss uses the simple overlay approach (no interactive transition for modals)
        handleSwbGesture(g, in: view) { [weak self] in
            self?.dismiss(animated: true)
        }
    }
}

// MARK: - Shared Gesture Helpers

private func makeSwbEdgeGesture(_ edge: UIRectEdge, target: AnyObject, action: Selector) -> UIScreenEdgePanGestureRecognizer {
    let g = SwbEdgeGestureRecognizer(target: target, action: action)
    g.edges = edge
    g.name  = "swb_edge"
    return g
}

/// Custom UIScreenEdgePanGestureRecognizer that resolves conflicts with UIScrollView.
private class SwbEdgeGestureRecognizer: UIScreenEdgePanGestureRecognizer, UIGestureRecognizerDelegate {

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        return other is UIPanGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
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

    /// Simple overlay-based gesture handler (used for present/dismiss).
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
                swb_dismissOverlay(springBack: false)
                if SwipeBackConfig.haptic { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                onComplete()
            } else {
                swb_dismissOverlay(springBack: true)
            }

        case .cancelled, .failed:
            swb_dismissOverlay(springBack: true)

        default: break
        }
    }

    func swb_dismissOverlay(springBack: Bool) {
        guard let overlay = objc_getAssociatedObject(self, &kOverlay) as? SwipeWaveOverlay else { return }
        if springBack {
            UIView.animate(
                withDuration: 0.4, delay: 0,
                usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8,
                options: [.curveEaseOut]
            ) {
                overlay.springBack()
            } completion: { _ in
                UIView.animate(withDuration: 0.15) { overlay.alpha = 0 } completion: { _ in
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

/// Full-screen transparent overlay that renders the Android-style back gesture indicator.
class SwipeWaveOverlay: UIView {

    private let isLeft: Bool
    private var fingerY: CGFloat = 0
    private var progress: CGFloat = 0
    var thresholdReached = false
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

    func update(fingerY: CGFloat, progress: CGFloat) {
        self.fingerY  = fingerY
        self.progress = progress
        setNeedsDisplay()
        updateChevron()
    }

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
        let p     = progress
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
        chevronLayer.path        = path.cgPath
        chevronLayer.frame       = bounds
        let white: CGFloat       = 0.45 + min(0.55, p * 1.1)
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

/// Android-style "Swipe again to exit" toast that slides in from the top.
class SwipeExitToast: UIView {

    init() { super.init(frame: .zero); setup() }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 22
        blur.clipsToBounds = true
        addSubview(blur)

        let label = UILabel()
        label.text      = "Swipe again to exit"
        label.font      = .systemFont(ofSize: 14, weight: .medium)
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

/// Optional `UINavigationController` subclass for explicit opt-in.
///
/// For app-wide support, prefer `SwipeBackManager.enable()` in AppDelegate.
///
/// **Usage:**
/// ```swift
/// let nav = SwipeBackNavigationController(rootViewController: homeVC)
/// ```
public class SwipeBackNavigationController: UINavigationController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Gesture setup handled automatically via swb_navViewDidLoad swizzle.
    }
}
