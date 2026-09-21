package com.booleanmaths.flutter

import android.content.Context
import android.content.Intent
import com.booleanmaths.sdk.BooleanMathsSDK
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlin.math.abs
import kotlin.math.floor

/**
 * Bridges the Dart API onto the native BooleanMaths Android SDK
 * (`com.booleanmaths:bm-sdk`) over a [MethodChannel].
 *
 * The plugin is [ActivityAware] purely for attribution: campaign data reaches
 * the SDK as an [Intent], and only an Activity has one.
 */
class BooleanMathsFlutterSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {
    private lateinit var channel: MethodChannel

    /**
     * Application context taken from the plugin binding. The SDK persists events
     * locally and syncs them through WorkManager, so it has to outlive any single
     * Activity — the application context is the correct scope, and the binding
     * provides it for as long as the engine is attached.
     */
    private lateinit var applicationContext: Context

    /**
     * Set while an Activity is attached. Only used to read the current intent;
     * the SDK itself is never handed an Activity.
     */
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // --- Activity attachment -------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    /**
     * A configuration change tears the Activity down and builds a new one. The
     * listener is registered against the *old* binding, so it has to be removed
     * here and re-added in [onReattachedToActivityForConfigChanges] — otherwise
     * every rotation leaks another registration.
     */
    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    /**
     * Every intent delivered to a running Activity — a deep link or notification
     * tap while the app is warm.
     *
     * Returns false so the intent stays available to other plugins; this is an
     * observer, not a consumer. `FlutterActivity.onNewIntent` has already called
     * `setIntent` by the time this runs, so the host app needs no `MainActivity`
     * override of its own.
     */
    override fun onNewIntent(intent: Intent): Boolean {
        runCatching { BooleanMathsSDK.handleIntent(intent) }
        return false
    }

    // --- Channel -------------------------------------------------------------

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "trackEvent" -> trackEvent(call, result)
            // Same behaviour under both names; the second is the deprecated alias.
            "handleIntent", "handleNotificationIntent" -> handleIntent(result)
            "flush" -> flush(result)
            "getHelloMessage" -> getHelloMessage(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(
        call: MethodCall,
        result: Result
    ) {
        val apiKey = call.argument<String>("apiKey")
        val pixelId = call.argument<String>("pixelId")

        if (apiKey.isNullOrBlank()) {
            result.error(ERROR_INVALID_ARGUMENT, "apiKey must be a non-empty string.", null)
            return
        }
        if (pixelId.isNullOrBlank()) {
            result.error(ERROR_INVALID_ARGUMENT, "pixelId must be a non-empty string.", null)
            return
        }

        val isDebug = call.argument<Boolean>("isDebug") ?: false
        val wrapperVersion = call.argument<String>("wrapperVersion")?.takeIf { it.isNotBlank() }
            ?: UNKNOWN_WRAPPER_VERSION

        try {
            // Before initialize: it emits FirstOpen and app_opened itself, and
            // those have to already carry wrapper_type / wrapper_version.
            BooleanMathsSDK.setWrapperConfig(WRAPPER_TYPE, wrapperVersion)

            BooleanMathsSDK.initialize(applicationContext, apiKey, pixelId, isDebug)

            // And again after: the SDK can only persist the wrapper config to
            // SharedPreferences once it holds an application context, which it
            // acquires inside initialize(). Without this second call the values
            // are lost on the next process start.
            BooleanMathsSDK.setWrapperConfig(WRAPPER_TYPE, wrapperVersion)

            // The SDK registers its ActivityLifecycleCallbacks inside
            // initialize(), which in a Flutter app runs long after
            // MainActivity was created — so it never saw the intent that
            // launched us. Hand it over explicitly or cold-start attribution
            // is lost. Re-forwarding is harmless; the SDK de-duplicates.
            forwardCurrentIntent()

            result.success(null)
        } catch (e: Throwable) {
            result.error(ERROR_SDK, "BooleanMathsSDK.initialize failed: ${e.message}", null)
        }
    }

    private fun trackEvent(
        call: MethodCall,
        result: Result
    ) {
        val eventName = call.argument<String>("eventName")
        if (eventName.isNullOrBlank()) {
            result.error(ERROR_INVALID_ARGUMENT, "eventName must be a non-empty string.", null)
            return
        }

        try {
            BooleanMathsSDK.trackEvent(eventName, normalizeProperties(call.argument("properties")))
            result.success(null)
        } catch (e: Throwable) {
            result.error(ERROR_SDK, "BooleanMathsSDK.trackEvent failed: ${e.message}", null)
        }
    }

    private fun handleIntent(result: Result) {
        try {
            forwardCurrentIntent()
            result.success(null)
        } catch (e: Throwable) {
            result.error(ERROR_SDK, "BooleanMathsSDK.handleIntent failed: ${e.message}", null)
        }
    }

    /**
     * Android has no flush: `bm-sdk` persists events to Room and syncs them via
     * WorkManager, which owns the timing. Reports false — "no flush performed" —
     * rather than true, which would read as a delivery guarantee the platform
     * cannot make.
     */
    private fun flush(result: Result) = result.success(false)

    private fun getHelloMessage(result: Result) {
        try {
            result.success(BooleanMathsSDK.getHelloMessage())
        } catch (e: Throwable) {
            result.error(ERROR_SDK, "BooleanMathsSDK.getHelloMessage failed: ${e.message}", null)
        }
    }

    /**
     * Hands the attached Activity's current intent to the SDK.
     *
     * A no-op when no Activity is attached — which happens for a headless
     * engine, or between `onDetachedFromActivity` and the next attach.
     */
    private fun forwardCurrentIntent() {
        activityBinding?.activity?.intent?.let { BooleanMathsSDK.handleIntent(it) }
    }

    // --- Property normalization ----------------------------------------------

    /**
     * Reads the `properties` argument — which the standard message codec hands
     * us as a `Map<*, *>` — into the `Map<String, Any>` the SDK expects.
     *
     * Non-string keys and null values are dropped rather than failing the call:
     * one malformed property should not cost the whole event.
     */
    internal fun normalizeProperties(raw: Map<*, *>?): Map<String, Any> {
        if (raw == null) return emptyMap()
        val normalized = LinkedHashMap<String, Any>(raw.size)
        for ((key, value) in raw) {
            if (key !is String) continue
            normalizeValue(value)?.let { normalized[key] = it }
        }
        return normalized
    }

    /** Returns null for a value that should be dropped from its parent map. */
    private fun normalizeValue(value: Any?): Any? =
        when (value) {
            null -> null
            is Double -> normalizeDouble(value)
            is Float -> normalizeDouble(value.toDouble())
            is Map<*, *> -> normalizeProperties(value)
            // Nulls are preserved inside a list: dropping one would shift the
            // index of every element after it, which changes what the data means.
            is List<*> -> value.map { normalizeValue(it) }
            else -> value
        }

    private fun normalizeDouble(value: Double): Any? {
        // Non-finite numbers have no JSON representation. Android's Gson would
        // write a bare NaN and produce invalid JSON; iOS drops the payload
        // outright. Dropped on both so the two platforms agree.
        if (!value.isFinite()) return null

        // Dart has no int/double distinction at a literal like `2`, so a count
        // often arrives as 2.0 and Gson renders it "2.0". Coerce back where the
        // value is whole and the conversion is exact — beyond 2^53 a Double can
        // no longer represent consecutive integers, so leave those alone.
        if (value == floor(value) && abs(value) <= MAX_EXACT_INTEGER_IN_DOUBLE) {
            return value.toLong()
        }
        return value
    }

    private companion object {
        const val CHANNEL_NAME = "com.booleanmaths/sdk_channel"
        const val ERROR_INVALID_ARGUMENT = "invalid_argument"
        const val ERROR_SDK = "sdk_error"
        const val WRAPPER_TYPE = "flutter"
        const val UNKNOWN_WRAPPER_VERSION = "unknown"

        /** 2^53 - 1: the largest integer a Double represents exactly. */
        const val MAX_EXACT_INTEGER_IN_DOUBLE = 9007199254740991.0
    }
}
