# SwipeBack

Android-style edge swipe navigation for iOS — both edges, elastic wave animation, works for push and present.

> This feature is not available in any existing iOS library. SloppySwiper only handles left-edge pop with no visual feedback. SwipeBack adds right-edge support, present/dismiss handling, and the Android elastic wave indicator.

## Features

- **Both edges** — left AND right edge swipe (Android 10+ style)
- **Push & Present** — works for `popViewController` AND `dismiss`
- **Android wave** — elastic bezier wave anchored to screen edge
- **Arrow indicator** — chevron grows inside the wave as you drag
- **Haptic feedback** — at gesture start and completion threshold
- **Zero config** — one line in AppDelegate, no subclassing

## Installation

### Swift Package Manager

In Xcode → File → Add Package Dependencies:
```
https://github.com/Kumar-ranjan12345/SwipeBack
```

### CocoaPods

```ruby
pod 'SwipeBack'
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

That's it. Every navigation controller and presented view controller in your app gets swipe-back automatically.

### Customization

```swift
SwipeBackManager.enable(
    leftEdge:  true,   // left edge → back (default: true)
    rightEdge: true,   // right edge → back (default: true)
    haptic:    true    // haptic feedback (default: true)
)
```

### Optional: Subclass

```swift
let nav = SwipeBackNavigationController(rootViewController: homeVC)
```

## How it works

- Swizzles `UINavigationController.viewDidLoad` to add edge gestures for push/pop
- Swizzles `UIViewController.viewDidAppear` to add edge gestures for present/dismiss
- Wave overlay uses a cubic bezier curve anchored to the screen edge
- Pop/dismiss only triggers on finger lift (not during drag) — exactly like Android

## Requirements

- iOS 14.0+
- Swift 5.9+
