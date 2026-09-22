# Consumer ProGuard rules for booleanmaths_flutter_sdk.
#
# These are packaged into the plugin's AAR and applied automatically to the host
# app's R8 run, so integrators need no ProGuard configuration of their own.

# WorkManager creates InputMerger implementations reflectively, via their
# no-argument constructor. androidx.work's own consumer rules keep the classes
# (`-keep class * extends androidx.work.InputMerger`) but not their
# constructors, and under R8 full mode — the default since AGP 8 — an
# unreferenced constructor is removed even from a kept class. The result at run
# time is:
#
#   E WM-InputMerger:  NoSuchMethodException: androidx.work.OverwritingInputMerger.<init> []
#   E WM-WorkerWrapper: Could not create Input Merger androidx.work.OverwritingInputMerger
#
# WorkerWrapper treats that as a failure and marks the work failed, so bm-sdk's
# EventWorker never runs. Events are persisted but never dispatched — a
# release-only failure that is silent unless isDebug is on.
-keep class * extends androidx.work.InputMerger { <init>(); }
