Pod::Spec.new do |s|
  s.name         = 'SwipeBack'
  s.version      = '1.0.0'
  s.summary      = 'Android-style edge swipe navigation for iOS — both edges, wave animation, push & present support.'
  s.description  = <<-DESC
    SwipeBack brings Android 10+ style back gesture to iOS.
    - Swipe from LEFT or RIGHT edge to go back
    - Works for pushed ViewControllers (pop) AND presented ones (dismiss)
    - Android-style elastic wave animation anchored to screen edge
    - Chevron arrow grows inside the wave as you drag
    - Haptic feedback at trigger threshold
    - Zero configuration — one line in AppDelegate
    - No subclassing required
  DESC
  s.homepage     = 'https://github.com/Kumar-ranjan12345/SwipeBack'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Kumar Ranjan' => 'kumar.ranjan.kamila@gmail.com' }
  s.platform     = :ios, '14.0'
  s.source       = { :git => 'https://github.com/Kumar-ranjan12345/SwipeBack.git', :tag => s.version.to_s }
  s.source_files = 'Sources/SwipeBack/**/*.swift'
  s.swift_version = '5.9'
end
