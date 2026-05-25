# SwipeBackKit

Android-style edge swipe navigation for iOS — predictive back, both edges, elastic wave animation, works for push and present.

> Most iOS swipe libraries fake an animation overlay and then suddenly pop. SwipeBackKit drives the real UIKit navigation transition with your finger — previous screen appears live as you drag, just like Android 14 and native iOS interactive pop.

## Features

- **Both edges** — left AND right edge swipe (Android 10+ style)
- **Push & Present** — works for `popViewController` AND `dismiss`
- **Android wave** — elastic bezier wave anchored to screen edge
- **Arrow indicator** — chevron grows inside the wave as you drag
- **Haptic feedback** — at gesture start and completion threshold
- **Scroll view safe** — no conflict with `UIScrollView`, `UITableView`, `UICollectionView`
- **Zero config** — one line in AppDelegate, no subclassing

## What's New in v1.3.1

Stable release. Same reliable 1.2.2 code base — no regressions.

## What's New in v1.2.0

- **Scroll view conflict fixed** — edge gesture wins when scroll view is at its leftmost/rightmost position
- **Half-screen present fixed** — swipe-back on background VC blocked when a sheet is presented on top

## What's New in v1.1.0

- **Disable per-screen** — `SwipeBackManager.disable(for: self)`
- **SwiftUI support** — `.swipeBackDisabled()` modifier
- **Spring-back animation** — wave bounces back to edge when gesture is cancelled
- **Double-swipe to exit** — swipe on root screen shows "Swipe again to exit" toast

## Installation

### Swift Package Manager

In Xcode → File → Add Package Dependencies:
```
https://github.com/Kumar-ranjan12345/SwipeBackKit
```

### CocoaPods

```ruby
pod 'SwipeBackKit'
```

## Usage

```swift
// AppDelegate.swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    SwipeBackManager.enable()
    return true
}
```

That's it. Every navigation controller and presented view controller in your app gets predictive swipe-back automatically.

### Customization

```swift
SwipeBackManager.enable(
    leftEdge:        true,   // left edge → back (default: true)
    rightEdge:       true,   // right edge → back (default: true)
    haptic:          true,   // haptic feedback (default: true)
    exitOnRootSwipe: true    // double-swipe to exit (default: true)
)

// Disable on a specific screen
override func viewDidLoad() {
    super.viewDidLoad()
    SwipeBackManager.disable(for: self)
}

// SwiftUI
MyView()
    .swipeBackDisabled()
```

### Optional: Subclass

```swift
let nav = SwipeBackNavigationController(rootViewController: homeVC)
```

## How it works

**v1.3.0 interactive transition:**
1. On `.began` — creates `SwbInteractiveTransition` (UIPercentDrivenInteractiveTransition), calls `popViewController(animated: true)` immediately
2. `SwbNavDelegate` (UINavigationControllerDelegate) provides `SwbSlideTransition` as the animation controller and the interaction controller
3. On `.changed` — calls `interactiveTransition.update(progress)` — this drives the actual VC transition live with the finger
4. On `.ended` — calls `finish()` or `cancel()` based on distance + velocity threshold
5. Wave overlay plays on top of the real transition throughout

**Slide transition:**
- Current VC slides out at 100% speed
- Previous VC slides in at 30% speed (parallax)
- Dim overlay on previous VC fades out as transition progresses

**Scroll view conflict:**
- `SwbEdgeGestureRecognizer` checks scroll view content offset
- Edge gesture only wins when scroll view is at its leftmost/rightmost position

## Requirements

- iOS 14.0+
- Swift 5.9+
