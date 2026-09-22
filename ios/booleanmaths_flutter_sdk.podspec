#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint booleanmaths_flutter_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'booleanmaths_flutter_sdk'
  s.version          = '0.2.1'
  s.summary          = 'Flutter plugin for the BooleanMaths SDK.'
  s.description      = <<-DESC
Bridges the Dart BooleanMaths API onto the native BooleanMaths iOS SDK: event
tracking, session handling and per-install first-open reporting, buffered on
device and dispatched in batches.
                       DESC
  s.homepage         = 'https://booleanmaths.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Medront Datalabs' => 'saurav@booleanmaths.com' }
  s.source           = { :path => '.' }
  s.source_files = 'booleanmaths_flutter_sdk/Sources/booleanmaths_flutter_sdk/**/*.swift'
  s.dependency 'Flutter'

  # '~> 1.2' is a floor as much as a ceiling. 1.0.0 is still published on Trunk
  # carrying an iOS 17.0 deployment target, which would silently break the
  # install for any app below iOS 17; 1.1.0 requires 15.1. Only 1.2.0 goes down
  # to 15.0, and its public API is identical to 1.1.0's, so there is nothing to
  # gain by allowing anything older.
  s.dependency 'BooleanMathsSDK', '~> 1.2'
  s.platform = :ios, '15.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  # The vendored SDK is built with library evolution against Swift 6 and needs
  # Xcode 16+ to read its .swiftinterface. This plugin's own sources compile in
  # the Swift 5 language mode.
  s.swift_version = '5.9'

  s.resource_bundles = {
    'booleanmaths_flutter_sdk_privacy' => ['booleanmaths_flutter_sdk/Sources/booleanmaths_flutter_sdk/PrivacyInfo.xcprivacy']
  }
end
