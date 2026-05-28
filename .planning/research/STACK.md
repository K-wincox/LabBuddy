# Stack Research: LabBuddy

**Date:** 2026-05-28
**Scope:** iOS-only, local-first wet-lab productivity app for Protocol scaling, daily execution, timers, inventory, calculators, and Data Cards.

## Recommendation

Build v1 as a native iOS app using SwiftUI, SwiftData, UserNotifications, ActivityKit/WidgetKit, App Intents, PhotosUI, and a lightweight image composition/export layer. Do not introduce cloud, accounts, or a cross-platform framework in v1.

## Core Stack

| Layer | Recommendation | Why |
|-------|----------------|-----|
| App UI | SwiftUI | Best fit for iOS-only, fast iteration, widgets/Live Activities shared UI, and modern Apple design patterns. |
| Persistence | SwiftData | Apple-native local persistence, declarative model definitions, efficient fetching, no external database dependency. |
| Timers and alerts | UserNotifications + in-app timer engine | Local notifications are the correct mechanism for bench timer alerts when the app is backgrounded or locked. |
| Lock screen / Dynamic Island | ActivityKit + WidgetKit | Live Activities are the Apple-native surface for glanceable ongoing timers and quick actions. |
| Actions / future voice hooks | App Intents | Required for Siri/Shortcuts exposure and for buttons/toggles inside Live Activities. |
| Images | PhotosUI + SwiftUI drawing/annotation canvas | Lets users attach gel/blot/cell images and annotate without pulling in heavy document tooling. |
| Data Card rendering | SwiftUI view snapshot or Core Graphics renderer | A Data Card is essentially a composed visual artifact; keep it deterministic and local. |
| Calculators | Pure Swift calculation services with unit tests | Scientific calculations need deterministic, testable core logic separated from UI. |

## Apple Platform Notes

SwiftData is appropriate for local Protocols, schedules, timers, inventory items, experiment records, and Data Card metadata. Apple describes it as declarative persistence with model fetching and no external dependencies.

ActivityKit is the correct mechanism for Live Activities. It can show ongoing state on the Lock Screen and Dynamic Island, but v1 must respect constraints: Live Activity data is small, presentations must be supported across supported devices, and an activity is time-limited. Long overnight steps should combine scheduled local notifications with a refreshed/scheduled activity rather than assuming one Live Activity can last forever.

UserNotifications should own timer completion alerts. The app should use clear notification titles/bodies such as "Gel run complete" and "Primary antibody incubation complete", because iOS notification sound customization and spoken announcements are constrained by system behavior and user settings.

App Intents should be designed early even if AI voice scheduling is deferred. They provide a clean future bridge for "start timer", "mark step done", or "open today's schedule", and can also power interactive buttons in widgets/Live Activities.

## Do Not Use in v1

- Cross-platform framework: Android is explicitly out of scope, and iOS-specific timer surfaces are central to the value.
- Backend database or account system: v1 is local-only.
- Cloud object storage: Data Cards and experiment images remain local in v1.
- Full LIMS/ELN framework: too heavy for a bench-side mobile tool.
- AI provider SDKs: AI scheduling and mentor-report assistant are post-v1 Pro capabilities.

## Sources

- Apple SwiftData documentation: https://developer.apple.com/documentation/SwiftData
- Apple SwiftUI persistent storage documentation: https://developer.apple.com/documentation/swiftui/persistent-storage
- Apple ActivityKit documentation: https://developer.apple.com/documentation/ActivityKit/
- Apple Live Activities guide: https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities
- Apple local notifications guide: https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app
- Apple AppIntent documentation: https://developer.apple.com/documentation/appintents/appintent
