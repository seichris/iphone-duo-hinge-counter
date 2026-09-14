# Implementation validation — 2026-09-14

## Executed locally

- Swift 6.2.1, `x86_64-unknown-linux-gnu`.
- `swift test`: **33 tests passed**, including a parameterized test with four invalid-angle cases.
- Swift syntax parsing of the app with and without `DUO_HINGE_API`, plus widget sources. Parsing is **not** SDK symbol/type validation.
- Generated Xcode project parsed successfully by `plutil` and Foundation's OpenStep property-list parser.
- Project/resource/scheme consistency checks and JSON/plist parsing.

## Not executed locally

This environment has no Xcode or iOS SDK/runtime. No local iOS app/widget build, simulator UI run, screenshot-based visual validation, physical iPhone Duo test, signing/archive, or App Store submission was performed.

The repository includes macOS CI to perform regular-scheme build/UI validation after push. Its actual run status is separate evidence, not implied by this file. The announced Duo SDK path remains unvalidated until a matching SDK is available and successfully builds it. Read TESTING.md before release.
