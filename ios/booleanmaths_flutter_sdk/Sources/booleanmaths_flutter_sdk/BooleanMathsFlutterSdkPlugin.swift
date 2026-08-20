import Flutter
import UIKit

/// iOS registration for the BooleanMaths Flutter plugin.
///
/// There is no native BooleanMaths iOS SDK yet, so the tracking methods answer
/// with `FlutterMethodNotImplemented`. The Dart layer turns that into a no-op,
/// which keeps shared Flutter code instrumented and running on iOS. Once an iOS
/// SDK exists, implement the cases below against it — the Dart API and the
/// channel contract do not need to change.
public class BooleanMathsFlutterSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.booleanmaths/sdk_channel", binaryMessenger: registrar.messenger())
    let instance = BooleanMathsFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
