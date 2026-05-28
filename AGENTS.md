<!-- GSD:project-start source:PROJECT.md -->
## Project

**LabBuddy**

LabBuddy is an iOS-first, local-first mobile productivity app for wet-lab researchers working at the bench. It is not a heavy desktop LIMS or ELN; it focuses on the high-frequency moments when a researcher is wearing gloves, juggling steps, timers, calculations, and quick reporting.

The product connects Protocol preparation, automatic recipe scaling, daily scheduling, multi-channel timers, lightweight execution records, inventory-aware consumption, buffer calculations, and shareable result cards into one bench-side loop: prepare -> execute -> record -> report.

**Core Value:** Wet-lab researchers can reliably execute and report daily experiments from their phone without losing track of protocols, timings, scaled reagent amounts, or key experimental metadata.

### Constraints

- **Platform**: iOS only for v1 — lock-screen timers, Live Activities/Dynamic Island, notification behavior, camera annotation, and local storage can be designed deeply for one platform first.
- **Data model**: Local-first personal data — no account, cloud sync, or team collaboration in v1.
- **AI scope**: AI features are Pro and post-v1 — manual scheduling and template-based reporting must work before AI voice scheduling or AI report generation.
- **Domain scope**: First release supports three experiment families — cell experiments, molecular cloning/plasmid workflows, and Western blot/gel workflows.
- **Interaction design**: Bench-side mobile use — core actions must be fast, large enough for gloved use, and readable under time pressure.
- **Business model**: Free/Pro split should preserve basic utility while reserving high-intensity workflow accelerators for Pro.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommendation
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
