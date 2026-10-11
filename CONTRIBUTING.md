# Contributing to SilkPlayer

Thank you for your interest in contributing to **SilkPlayer**.

SilkPlayer is an open-source, native media player engineered for macOS using Swift 6, AppKit, SwiftUI, and SilkCoreKit (SilkPlayback Engine, SilkRender Pipeline, SilkThumb Engine).

---

## 1. Development Requirements

To build and run tests locally, your development environment must satisfy:

- **Operating System**: macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- **Architecture**: Apple Silicon (arm64: M1/M2/M3/M4 families)
- **Toolchain**: Xcode 16.0+ or Swift 6.0 command-line tools
- **Package Manager**: Swift Package Manager (dependencies are resolved automatically via `Package.swift`)

No third-party package managers (such as Homebrew) are required to build the core application.

---

## 2. Engineering Guidelines

Contributions should adhere to the following architectural conventions:

### A. Swift 6 Strict Concurrency
- The codebase enforces complete concurrency checking (`.swiftLanguageMode(.v6)`).
- Contributions should compile cleanly with zero concurrency warnings or data races.
- UI components, view models, and window controllers should be properly isolated to `@MainActor`.
- Cross-actor models and values must conform to `Sendable`.

### B. AppKit & SwiftUI Separation
- Use **SwiftUI** for view layout, controls, preferences, and state-driven interfaces.
- Use **AppKit** for window lifecycle (`NSWindow`, `NSWindowController`), event routing (`NSEvent` monitors), and menu bar actions.
- Ensure modal dialogs (Settings, Cheatsheet, Inspector) handle their own keyboard shortcuts (e.g. `Esc`, `⌘W`) to prevent unintended actions in the underlying player window.

### C. Resource Lifecycle Management
- Ensure hardware decoder allocations, playback sessions, and Metal render resources are systematically released upon closing windows or stopping playback.
- Avoid polling loops or unbounded background timers. Use reactive Combine publishers, system notifications, or event-driven callbacks.

### D. Apple Human Interface Guidelines
- Adhere to the [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/).
- Use standardized industry and macOS terminology in code, comments, and localized strings.

---

## 3. Testing & Verification

All contributions must pass the automated test suite prior to submission.

```bash
# Run the automated regression tests
./scripts/run_tests.sh
```

- When resolving bugs or adding features, include corresponding test assertions in `Tests/SilkPlayerTests/PlaylistTests.swift`.
- Ensure all tests pass (`0 failed`) before opening a pull request.

---

## 4. Release Build & Packaging Verification

To verify that the application compiles and packages cleanly into a release disk image:

```bash
./scripts/package_app.sh
```

---

## 5. Pull Request Process

1. **Branching**: Create a feature or fix branch from `main` (e.g., `git checkout -b fix/subtitle-delay-binding`).
2. **Commit Messages**: Follow standard [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` for new functionality
   - `fix:` for bug fixes
   - `refactor:` for code restructuring without behavior changes
   - `perf:` for performance optimizations
   - `docs:` for documentation updates
   - `test:` for test additions or updates
3. **Local Validation**:
   - Verify that `./scripts/run_tests.sh` passes completely.
   - Verify that `swift build` finishes with zero warnings.
4. **Submission**: Open a Pull Request on GitHub with a description of the changes, the rationale, and testing steps.
