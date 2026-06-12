# SwipeBackKit

Android-style edge swipe navigation for iOS — both edges, elastic wave animation, works for push and present.

## Features

- **Both edges** — left AND right edge swipe (Android 10+ style)
- **Push & Present** — works for `popViewController` AND `dismiss`
- **Android wave** — elastic bezier wave anchored to screen edge
- **Arrow indicator** — chevron grows inside the wave as you drag
- **Haptic feedback** — at gesture start and completion threshold
- **Scroll view safe** — no conflict with `UIScrollView`, `UITableView`, `UICollectionView`
- **Double-swipe to exit** — swipe left or right on root screen shows "Swipe again to exit" toast; second swipe within 2 seconds moves app to background
- **No iOS conflict** — iOS's built-in `interactivePopGestureRecognizer` is fully suppressed; no double-pop
- **View-based overlay support** — `SwipeBackOverlayRegistry` blocks swipe gesture while any bottom sheet or popup is visible
- **Disable per-screen** — `SwipeBackManager.disable(for: self)`
- **SwiftUI support** — `.swipeBackDisabled()` modifier
- **Spring-back animation** — wave bounces back to edge when gesture is cancelled
- **Zero config** — one line in AppDelegate, no subclassing

## What's New in v1.4.0

- **Overlay swipe-to-dismiss** — `SwipeBackOverlayRegistry.register(_:onDismiss:)` now attaches the edge gesture directly to the overlay view. Swiping on the sheet shows the wave animation and calls your dismiss closure — exactly like swiping on a presented VC
- **Breaking change** — `register(_:)` now requires an `onDismiss` closure: `register(self, onDismiss: { self.dismiss() })`

## What's New in v1.3.9

- **Right edge on root** — right edge now also shows "Swipe again to exit" toast and exits on double swipe (same as left)
- **Wave on root swipe** — the elastic wave animation now plays even when swiping on the root screen before showing the toast

## What's New in v1.3.8

- **Wave animation on root** — root screen swipes now go through `handleSwbGesture`, so the wave plays before `triggerExitBehavior` fires
- **Clean double-swipe logic** — `triggerExitBehavior()` replaces old `handleRootSwipe(gesture:)` — no gesture params needed since threshold is already handled

## What's New in v1.3.7

- **Fixed: left edge conflicting with iOS default pop** — replaced `interactivePopGestureRecognizer?.delegate = nil` (which re-enables the built-in gesture) with `SwbNeverDelegate` — a permanent deny-all delegate that fully suppresses the built-in gesture
- **Fixed: right edge showing exit toast on root** — right edge now has its own handler `swb_navPanRight` that previously silently ignored root (now fixed in 1.3.9 to also trigger exit)

## What's New in v1.3.6

- **`SwipeBackOverlayRegistry`** — register view-based bottom sheets and popups so the swipe gesture is blocked while they are visible
- Thread-safe with `NSLock`
- Leak-safe via `NSHashTable.weakObjects()` — auto-cleans deallocated entries

## Installation

### Swift Package Manager

In Xcode → File → Add Package Dependencies:
```
https://github.com/Kumar-ranjan12345/SwipeBackKit
```

### CocoaPods

```ruby
pod 'SwipeBackKit', '~> 1.4.0'
```

> If the CDN hasn't propagated yet, install directly from GitHub:
> ```ruby
> pod 'SwipeBackKit', :git => 'https://github.com/Kumar-ranjan12345/SwipeBackKit.git', :tag => '1.4.0'
> ```

## Usage

### Basic setup

```swift
// AppDelegate.swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    SwipeBackManager.enable()
    return true
}
```

That's it. Every navigation controller and presented view controller in your app gets swipe-back automatically.

### Customization

```swift
SwipeBackManager.enable(
    leftEdge:        true,   // left edge → back (default: true)
    rightEdge:       true,   // right edge → back (default: true)
    haptic:          true,   // haptic feedback (default: true)
    exitOnRootSwipe: true    // double-swipe to exit on root screen (default: true)
)
```

### Disable on a specific screen

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    SwipeBackManager.disable(for: self)
}
```

### SwiftUI

```swift
MyView()
    .swipeBackDisabled()
```

### Optional subclass

```swift
let nav = SwipeBackNavigationController(rootViewController: homeVC)
```

---

## SwipeBackOverlayRegistry

Use this when you show a bottom sheet, popup, or drawer **as a subview** (not as a presented `UIViewController`). While registered, the swipe gesture is blocked on the underlying navigation controller.

### Add to your popup/bottom-sheet view

```swift
override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
        SwipeBackOverlayRegistry.register(self)
    } else {
        SwipeBackOverlayRegistry.unregister(self)
    }
}
```

That's all. No changes needed in the presenting view controller.

### Full example with dismiss

```swift
// Inside your bottom sheet view class:

override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
        SwipeBackOverlayRegistry.register(self)
    } else {
        SwipeBackOverlayRegistry.unregister(self)
    }
}

func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
    UIView.animate(withDuration: animated ? 0.3 : 0, options: .curveEaseIn) {
        self.dimView.alpha = 0
        self.bottomConstraint.constant = Layout.sheetOffset
        self.layoutIfNeeded()
    } completion: { _ in
        self.removeFromSuperview() // triggers didMoveToWindow(nil) → auto-unregisters
        completion?()
    }
}

// When showing:
func showFromRoot() {
    guard let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })?
        .windows.first(where: { $0.isKeyWindow })
    else { return }
    frame = window.bounds
    window.addSubview(self) // triggers didMoveToWindow → auto-registers
    // ... animate in
}
```

---

## Double-swipe to exit

When `exitOnRootSwipe: true` (default), swiping from **either edge** on the root screen:

1. **First swipe** — elastic wave plays, then toast appears: *"Swipe again to exit"*
2. **Second swipe within 2 seconds** — elastic wave plays, then app moves to background
3. **After 2 seconds** — timer resets, next swipe is treated as first again

---

## How gesture conflict is resolved

| Scenario | Behaviour |
|---|---|
| iOS built-in pop gesture | Suppressed via `SwbNeverDelegate` — never fires |
| Left edge, multiple VCs | Our wave plays, then `popViewController` |
| Right edge, multiple VCs | Our wave plays, then `popViewController` |
| Left edge, root screen | Our wave plays, then toast / exit |
| Right edge, root screen | Our wave plays, then toast / exit |
| Any edge, modal presented | Gesture blocked (`presentedViewController != nil`) |
| Any edge, overlay registered | Gesture blocked (`SwipeBackOverlayRegistry.hasActiveOverlay`) |
| Any edge, VC disabled | Gesture blocked (`SwipeBackManager.isDisabled(for:)`) |

---

## Requirements

- iOS 14.0+
- Swift 5.9+
