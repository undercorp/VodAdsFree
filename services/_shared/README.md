# _shared

Kotlin helpers compiled into the bundle alongside every service's patches.

- `MethodStubs.kt` - `returnEarly()` (make a method return void/false/0/null/empty list at its
  first instruction), `MethodDescriptor` (parse `Lpkg/Cls;->m(I)Z`), `methodByDescriptor()`.
- `MethodTargets.kt` - `applyMethodTargets()`: applies a list of descriptors from a patch option
  (used by the Netflix and HBO Max patches, whose targets change every app version).
