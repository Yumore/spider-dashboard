# Findings & Decisions

## Requirements
- User explicitly requested repairing the `flutter build apk` failure; APK build is authorized.
- The worktree is on `main` at `6f74ffb`; tracked files are clean. Only untracked Rust `target/` artifacts are present.
- The connected device is a Pixel 6 Pro; `ro.eink.model` returned an empty value. Per the user-supplied project rules, use the default Android channel.
- `android/gradle.properties` sets `org.gradle.parallel=true`; no Gradle build was active before the build. Flutter has no generic Gradle-argument forwarder, so the build used equivalent `-Dorg.gradle.workers.max=6 -Dorg.gradle.parallel=false` JVM properties.
- Local Flutter is 3.50.0 stable with Dart 3.14.0.
- The release build reaches `:app:buildNovelSoundRust` and fails because `rustc` cannot find `core`/`std` for `aarch64-linux-android` (`E0463`). The `rustc`/`cargo` initially came from MacPorts under `/opt/local/bin`, built for host `x86_64-apple-darwin`; the target libraries were absent. Installed a user-scoped Rustup 1.99.1 toolchain with both Android targets. For the build, place `/Users/nathaniel/.cargo/bin` first in PATH and set `RUSTUP_TOOLCHAIN=1.99.1` so the project script uses the same compiler version with the added target libraries.
- `packages/novel_sound/scripts/build_rust_backend.sh` cross-compiles both `aarch64-linux-android` and `armv7-linux-androideabi` with the pinned Android NDK, but does not check or provision Rust target standard libraries before invoking Cargo.
- After the Rust target was available, Kotlin compilation found that `CryptoNative.kt` imports OkHttp APIs without the app module declaring OkHttp; added the direct app dependency.
- Dart compilation then exposed independent source/API drift: unsupported `final` parameter modifiers in `eso_api_from_rule.dart`; missing Cupertino import for `CupertinoPageTransitionsBuilder`; and `xml` 6.6.1's DAV namespace parameter is named `namespace` rather than `namespaceUri`.
- Plugin resolution was inconsistent across the root and path packages: Workmanager was constrained to interface 0.9.3 while 0.9.3's Apple plugin expects a newer interface; nativeapi 0.5.10's normal runner used a Dart API unavailable on Dart 3.14; and tray_manager/screen_retriever constraints lagged their Dart 3.14-compatible releases. Aligned these path-package constraints and removed obsolete root Workmanager overrides.
- Root `flutter pub get` and `packages/guomu` `flutter pub get` both resolve successfully after the dependency updates. The first final release build passed Dart, Flutter AOT, Kotlin, CMake/Rust, and Android resource tasks but failed at `:app:minifyReleaseWithR8` because SMBJ references Java SE `org.ietf.jgss` GSS types. The app's SMB bridge explicitly configures `NtlmAuthenticator`; its Android use does not require the optional Kerberos/GSS path. Added generated exact `-dontwarn` rules in an app-owned ProGuard file and wired that file into release configuration; a second build succeeded.
- A normal shell still resolves `/opt/local/bin/rustc` before Rustup, which lacks the Android targets. Updated `build_rust_backend.sh` to prefer Rustup shims when available, select the active per-project toolchain, and report the exact `rustup target add` command if either Android target is missing. The final `flutter build apk --release --verbose` succeeded without manual Rust PATH/toolchain overrides.

## Research Findings
- Verified upstream compatibility/version details in the package changelogs: Workmanager 0.10.10, tray_manager 0.9.0, screen_retriever 0.4.0, and nativeapi 0.6.1. References: https://pub.dev/packages/workmanager/versions/0.10.10, https://pub.dev/packages/tray_manager/changelog, https://pub.dev/publishers/leanflutter.dev/packages, https://pub.dev/packages/nativeapi.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Keep Rustup toolchain and Android targets user-local; do not add a repository pin. | The build host lacked Rust's Android standard libraries, and this resolves the local toolchain gap without changing project-wide toolchain policy. |
| Align direct constraints in affected path packages and lockfiles. | Root and nested package resolution must agree on APIs compatible with Flutter 3.50 / Dart 3.14. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Rust Android `core`/`std` target libraries absent. | Installed Rustup 1.99.1 with both required Android targets and built with it selected in PATH. |
| Missing direct OkHttp declaration for Android Kotlin use. | Added `com.squareup.okhttp3:okhttp:4.12.0` to `android/app/build.gradle`. |
| Dart/XML/plugin compile API mismatch. | Corrected source API use and aligned Workmanager, nativeapi, tray_manager, and screen_retriever dependency constraints. |
| R8 rejected SMBJ's optional Java SE GSS references absent from Android. | Added the generated exact GSS `-dontwarn` rules; the app SMB integration uses NTLM authentication. A second release build is required to confirm. |

## Resources
- Build logs: `/tmp/dashboard-flutter-build-20261119.log`, `/tmp/dashboard-flutter-build-20261119-retry.log`, `/tmp/dashboard-flutter-build-20261119-final.log`, `/tmp/dashboard-flutter-build-20261119-fixed.log`.
