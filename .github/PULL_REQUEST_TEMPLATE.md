## Description

Please provide a summary of your change, the architectural rationale, and the problem it solves.

- Closes #(issue)

---

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Refactoring (code improvements with no behavioral changes)
- [ ] Performance optimization (CPU / memory / buffer improvements)
- [ ] Documentation update

---

## Verification & Testing

Please describe the tests and steps you performed to verify your changes:

- [ ] Tested locally on Apple Silicon Mac (`macOS 14` or `macOS 15`)
- [ ] All automated tests pass: `./scripts/run_tests.sh`
- [ ] Release build succeeds: `swift build -c release`
- [ ] Swift 6 Strict Concurrency: Zero concurrency warnings (`-strict-concurrency=complete`)
- [ ] Verified event isolation: Modal keys/mouse do not interfere with background playback
- [ ] Verified resource cleanup: Window close releases textures and resources cleanly

---

## Checklist

- [ ] My code adheres to the project's coding standards and Apple HIG.
- [ ] I have self-reviewed my own code.
- [ ] I have commented complex or non-obvious code sections.
- [ ] Any added features or fixed bugs have corresponding tests in `Tests/SilkPlayerTests/PlaylistTests.swift`.
