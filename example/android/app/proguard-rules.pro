# Intentionally empty.
#
# This example keeps no BooleanMaths keep rules of its own, which is the point:
# `com.booleanmaths:bm-sdk` 1.0.13+ ships its own consumer ProGuard rules inside
# the AAR, and consumer rules are applied to the host app automatically. If a
# release build here survives R8 with this file empty, then a real integrator
# needs no ProGuard configuration either.
#
# Verify after `flutter build apk --release`:
#
#   grep "com.booleanmaths.sdk" build/app/outputs/mapping/release/mapping.txt
#
# Classes must map to themselves. If they map to short names like `a.a.b`, the
# consumer rules did not apply and event JSON keys will be obfuscated — the
# failure mode that bm-sdk 1.0.12 and earlier shipped with.
