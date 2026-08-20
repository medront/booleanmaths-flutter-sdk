package com.booleanmaths.flutter

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * Unit tests for the argument handling in the Kotlin side of the plugin.
 *
 * These cover the paths that do not reach into the native SDK — validation and
 * method routing. Anything that actually calls BooleanMathsSDK needs a real
 * Android context, so it belongs in the example app's integration tests.
 *
 * Run with `./gradlew testDebugUnitTest` in `example/android/`.
 */
internal class BooleanMathsFlutterSdkPluginTest {
    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = BooleanMathsFlutterSdkPlugin()

        val call = MethodCall("getPlatformVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
    }

    @Test
    fun onMethodCall_unknownMethod_reportsNotImplemented() {
        val plugin = BooleanMathsFlutterSdkPlugin()

        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("thereIsNoSuchMethod", null), mockResult)

        Mockito.verify(mockResult).notImplemented()
    }

    @Test
    fun onMethodCall_initializeWithBlankApiKey_reportsInvalidArgument() {
        val plugin = BooleanMathsFlutterSdkPlugin()

        val call = MethodCall("initialize", mapOf("apiKey" to "  ", "pixelId" to "pixel-456"))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).error(
            Mockito.eq("invalid_argument"),
            Mockito.contains("apiKey"),
            Mockito.isNull()
        )
    }

    @Test
    fun onMethodCall_initializeWithMissingPixelId_reportsInvalidArgument() {
        val plugin = BooleanMathsFlutterSdkPlugin()

        val call = MethodCall("initialize", mapOf("apiKey" to "key-123"))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).error(
            Mockito.eq("invalid_argument"),
            Mockito.contains("pixelId"),
            Mockito.isNull()
        )
    }

    @Test
    fun onMethodCall_trackEventWithBlankName_reportsInvalidArgument() {
        val plugin = BooleanMathsFlutterSdkPlugin()

        val call = MethodCall("trackEvent", mapOf("eventName" to "", "properties" to emptyMap<String, Any>()))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).error(
            Mockito.eq("invalid_argument"),
            Mockito.contains("eventName"),
            Mockito.isNull()
        )
    }
}
