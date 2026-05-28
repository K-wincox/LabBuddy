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
- App-local labeled timers can be started from experiment cards and persist between launches.
- Bench Mode opens a focused, large-control execution view for one active experiment.
- Protocol tab previews proportional recipe scaling and imports scaled runs into Today.
- Tools tab shows common buffer/calculation examples.
- Share buttons open a first Data Card preview with run metadata and LabBuddy branding.

## First walkthrough

1. Start on the Today tab.
2. Tap `实验台` on any run to enter the focused bench-side view.
3. Mark steps complete with the large check controls.
4. Start a timer from the bench view or experiment card.
5. Open the Protocol tab, adjust the target volume, and tap `导入今日安排`.
6. Return to Today to see the newly imported scaled run.
7. Tap the share button on a run to preview the first Data Card.

## Verification status

The repository currently has Swift source type-checking and project-file validation. Full `xcodebuild` verification requires full Xcode; this machine currently only has Command Line Tools.
