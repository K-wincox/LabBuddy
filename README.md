# LabBuddy

LabBuddy is a local-first iOS app prototype for wet-lab researchers. The first usable build focuses on a today-first bench workflow: scheduled runs, step completion, protocol scaling previews, and quick calculator examples.

## Open locally

1. Install Xcode from the Mac App Store.
2. Open `LabBuddy.xcodeproj`.
3. Select an iPhone simulator.
4. Run the `LabBuddy` scheme.

## Current prototype

- Native SwiftUI app, iOS 17.0 target.
- No sign-in, cloud sync, account system, AI provider, or external dependency.
- Today tab with seeded cell experiment, plasmid prep, and Western blot/gel work.
- Step completion state persists locally with `@AppStorage`.
- Protocol tab previews proportional recipe scaling.
- Tools tab shows common buffer/calculation examples.

## Verification status

The repository currently has Swift source type-checking and project-file validation. Full `xcodebuild` verification requires full Xcode; this machine currently only has Command Line Tools.
