import BooleanMathsSDK
import Flutter
import UIKit

/// Bridges the Dart API onto the native BooleanMaths iOS SDK over a
/// `FlutterMethodChannel`.
///
/// `BooleanMaths` is a pure-Swift, `@MainActor` type with no Objective-C
/// surface. That is fine here because this plugin is itself Swift and can
/// `import BooleanMathsSDK` directly — no bridging shim is needed.
public class BooleanMathsFlutterSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.booleanmaths/sdk_channel",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(BooleanMathsFlutterSdkPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initialize(call, result)
    case "trackEvent":
      trackEvent(call, result)
    case "handleIntent", "handleNotificationIntent":
      // iOS has no intent concept and the SDK reports no attribution data.
      // Answering successfully keeps shared Dart code branch-free.
      result(nil)
    case "flush":
      flush(call, result)
    case "getHelloMessage":
      // `nonisolated static` — no main-actor hop needed.
      result(BooleanMaths.getHelloMessage())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Methods

  private func initialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]

    guard let apiKey = arguments["apiKey"] as? String, !apiKey.isBlank else {
      result(Self.invalidArgument("apiKey must be a non-empty string."))
      return
    }
    guard let pixelId = arguments["pixelId"] as? String, !pixelId.isBlank else {
      result(Self.invalidArgument("pixelId must be a non-empty string."))
      return
    }

    let isDebug = arguments["isDebug"] as? Bool ?? false
    let wrapperVersion = (arguments["wrapperVersion"] as? String)
      .flatMap { $0.isBlank ? nil : $0 } ?? "unknown"

    // Exactly once, and before initialize: `initialize` emits FirstOpen and
    // app_opened itself, and those must already carry the wrapper fields.
    //
    // Unlike Android, this must NOT be repeated afterwards —
    // `WrapperConfigStore.set` writes to UserDefaults unconditionally, while
    // `initialize` calls `rehydrate()`, which fills each field only where it is
    // still nil. One call before is correct and sufficient.
    BooleanMaths.shared.setWrapperConfig(type: "flutter", version: wrapperVersion)

    onMainActor {
      BooleanMaths.shared.initialize(apiKey: apiKey, pixelId: pixelId, isDebug: isDebug)
    }
    result(nil)
  }

  private func trackEvent(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]

    guard let eventName = arguments["eventName"] as? String, !eventName.isBlank else {
      result(Self.invalidArgument("eventName must be a non-empty string."))
      return
    }

    let properties = Self.sanitized(arguments["properties"] as? [String: Any])
    onMainActor {
      BooleanMaths.shared.track(eventName, properties: properties)
    }
    result(nil)
  }

  private func flush(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    let timeout = (arguments["timeoutSeconds"] as? NSNumber)?.doubleValue ?? 30

    onMainActor {
      BooleanMaths.shared.flush(timeout: timeout) { success in
        result(success)
      }
    }
  }

  // MARK: - Main-actor isolation

  /// Runs `body` on the main actor.
  ///
  /// Flutter dispatches platform-channel calls on the main thread, so we are
  /// already there — `assumeIsolated` states that rather than re-scheduling.
  /// `DispatchQueue.main.async` would run the SDK call *after* the enclosing
  /// method has already returned its result, which makes ordering untestable;
  /// `dispatch_sync` onto the main queue from the main queue deadlocks.
  private func onMainActor(_ body: @MainActor () -> Void) {
    if Thread.isMainThread {
      MainActor.assumeIsolated(body)
    } else {
      // Defensive: only reachable if a future Flutter release moves channel
      // dispatch off the main thread. Correctness beats ordering here.
      DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
    }
  }

  // MARK: - Property sanitization

  /// Strips values that would make the payload unserializable.
  ///
  /// The SDK's `EventDispatcher` and `EventStore` both guard on
  /// `JSONSerialization.isValidJSONObject` and *silently discard* the payload
  /// when it returns false. `isValidJSONObject` rejects non-finite `NSNumber`s,
  /// so one `NaN` property would cost the event — or the entire batch it ships
  /// in. Dropping them here is the difference between losing one property and
  /// losing the data.
  private static func sanitized(_ raw: [String: Any]?) -> [String: Any] {
    guard let raw else { return [:] }
    var sanitized: [String: Any] = [:]
    sanitized.reserveCapacity(raw.count)
    for (key, value) in raw {
      if let value = sanitizedValue(value) {
        sanitized[key] = value
      }
    }
    return sanitized
  }

  /// Returns nil for a value that should be dropped from its parent dictionary.
  private static func sanitizedValue(_ value: Any) -> Any? {
    switch value {
    case is NSNull:
      return nil
    case let number as NSNumber:
      // Covers Bool and every integer width too: their `doubleValue` is always
      // finite, so only genuine floating-point NaN/±infinity is rejected.
      return number.doubleValue.isFinite ? number : nil
    case let dictionary as [String: Any]:
      return sanitized(dictionary)
    case let array as [Any]:
      // Positions are preserved: a dropped element would shift the index of
      // everything after it, changing what the array means. Anything that
      // cannot be represented becomes an explicit null instead.
      return array.map { sanitizedValue($0) ?? NSNull() }
    default:
      return value
    }
  }

  private static func invalidArgument(_ message: String) -> FlutterError {
    FlutterError(code: "invalid_argument", message: message, details: nil)
  }
}

private extension String {
  /// Matches Kotlin's `isNullOrBlank` so both platforms reject the same input.
  var isBlank: Bool {
    trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
