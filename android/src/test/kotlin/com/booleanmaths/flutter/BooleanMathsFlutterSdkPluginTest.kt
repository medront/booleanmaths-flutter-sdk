package com.booleanmaths.flutter

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/*
 * Unit tests for the argument handling in the Kotlin side of the plugin.
 *
 * These cover the paths that do not reach into the native SDK — validation,
 * method routing and property normalization. Anything that actually calls
 * BooleanMathsSDK needs a real Android context, so it belongs in the example
 * app's integration tests.
 *
 * Run with `./gradlew testDebugUnitTest` in `example/android/`.
 */
internal class BooleanMathsFlutterSdkPluginTest {
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

    /**
     * Android has no flush. Reporting false rather than true keeps the Dart
     * result honest: nothing was dispatched.
     */
    @Test
    fun onMethodCall_flush_reportsFalseWithoutDispatching() {
        val plugin = BooleanMathsFlutterSdkPlugin()

        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("flush", mapOf("timeoutSeconds" to 5.0)), mockResult)

        Mockito.verify(mockResult).success(false)
    }

    // --- Property normalization ---------------------------------------------

    @Test
    fun normalizeProperties_nullMap_isEmpty() {
        assertEquals(emptyMap(), BooleanMathsFlutterSdkPlugin().normalizeProperties(null))
    }

    @Test
    fun normalizeProperties_dropsNullValuesAndNonStringKeys() {
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(
            mapOf("keep" to "yes", "drop" to null, 7 to "non-string key")
        )

        assertEquals(mapOf<String, Any>("keep" to "yes"), normalized)
    }

    /**
     * Gson renders a whole Double as "3.0". Dart has no int/double distinction
     * at a literal, so a count routinely arrives as 2.0 and would be reported
     * as "2.0" rather than "2".
     */
    @Test
    fun normalizeProperties_coercesWholeDoublesToLong() {
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(
            mapOf("quantity" to 2.0, "zero" to 0.0, "negative" to -7.0)
        )

        assertEquals(2L, normalized["quantity"])
        assertEquals(0L, normalized["zero"])
        assertEquals(-7L, normalized["negative"])
    }

    @Test
    fun normalizeProperties_leavesFractionalDoublesAlone() {
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(
            mapOf("price" to 499.99)
        )

        assertEquals(499.99, normalized["price"])
    }

    /**
     * Past 2^53 a Double can no longer represent consecutive integers, so
     * coercing would report a different number than the caller passed.
     */
    @Test
    fun normalizeProperties_leavesDoublesBeyondExactIntegerRangeAlone() {
        val huge = 1.0e300
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(mapOf("huge" to huge))

        assertEquals(huge, normalized["huge"])
    }

    /**
     * Non-finite numbers have no JSON representation: Gson would emit invalid
     * JSON and iOS discards the payload outright. Dropped on both platforms so
     * they agree.
     */
    @Test
    fun normalizeProperties_dropsNonFiniteDoubles() {
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(
            mapOf(
                "nan" to Double.NaN,
                "infinity" to Double.POSITIVE_INFINITY,
                "negative_infinity" to Double.NEGATIVE_INFINITY,
                "fine" to 1.5
            )
        )

        assertEquals(mapOf<String, Any>("fine" to 1.5), normalized)
    }

    @Test
    fun normalizeProperties_recursesIntoNestedMaps() {
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(
            mapOf("nested" to mapOf("count" to 3.0, "drop" to null))
        )

        assertEquals(mapOf<String, Any>("count" to 3L), normalized["nested"])
    }

    /**
     * Dropping a null from a list would shift the index of everything after it,
     * which changes what the data means. Nulls are kept in place.
     */
    @Test
    fun normalizeProperties_preservesNullsInsideLists() {
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(
            mapOf("items" to listOf("a", null, "c"))
        )

        assertEquals(listOf("a", null, "c"), normalized["items"])
    }

    @Test
    fun normalizeProperties_normalizesListElementsInPlace() {
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(
            mapOf("values" to listOf(1.0, Double.NaN, 2.5))
        )

        // The NaN becomes null rather than vanishing, so 2.5 stays at index 2.
        assertEquals(listOf(1L, null, 2.5), normalized["values"])
    }

    @Test
    fun normalizeProperties_passesThroughCodecPrimitives() {
        val normalized = BooleanMathsFlutterSdkPlugin().normalizeProperties(
            mapOf("s" to "text", "b" to true, "i" to 42, "l" to 42L)
        )

        assertEquals("text", normalized["s"])
        assertEquals(true, normalized["b"])
        assertEquals(42, normalized["i"])
        assertEquals(42L, normalized["l"])
        assertTrue(normalized.size == 4)
    }
}
