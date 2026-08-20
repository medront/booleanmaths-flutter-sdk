package com.booleanmaths.flutter

import android.content.Context
import com.booleanmaths.sdk.BooleanMathsSDK
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Bridges the Dart API onto the native BooleanMaths Android SDK
 * (`com.booleanmaths:bm-sdk`) over a [MethodChannel].
 */
class BooleanMathsFlutterSdkPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel

    /**
     * Application context taken from the plugin binding. The SDK persists events
     * locally and syncs them through WorkManager, so it has to outlive any single
     * Activity — the application context is the correct scope, and the binding
     * provides it for as long as the engine is attached.
     */
    private lateinit var applicationContext: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "trackEvent" -> trackEvent(call, result)
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
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

        try {
            BooleanMathsSDK.initialize(applicationContext, apiKey, pixelId)
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
            BooleanMathsSDK.trackEvent(eventName, call.propertiesArgument())
            result.success(null)
        } catch (e: Throwable) {
            result.error(ERROR_SDK, "BooleanMathsSDK.trackEvent failed: ${e.message}", null)
        }
    }

    /**
     * Reads the `properties` argument — which the standard message codec hands us
     * as a `Map<*, *>` — into the `Map<String, Any>` the SDK expects.
     *
     * Non-string keys and null values are dropped rather than failing the call:
     * one malformed property should not cost the whole event.
     */
    private fun MethodCall.propertiesArgument(): Map<String, Any> {
        val raw = argument<Map<*, *>>("properties") ?: return emptyMap()
        return raw.entries
            .mapNotNull { (key, value) ->
                if (key is String && value != null) key to value else null
            }.toMap()
    }

    private companion object {
        const val CHANNEL_NAME = "com.booleanmaths/sdk_channel"
        const val ERROR_INVALID_ARGUMENT = "invalid_argument"
        const val ERROR_SDK = "sdk_error"
    }
}
