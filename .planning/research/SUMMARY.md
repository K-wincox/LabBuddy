# Research Summary: LabBuddy

**Date:** 2026-05-28

## Key Findings

**Stack:** Native iOS is the right v1 path. Use SwiftUI, SwiftData, UserNotifications, ActivityKit/WidgetKit, App Intents, PhotosUI, and pure Swift calculation services.

**Table stakes:** Protocol templates, run/checklist mode, recipe scaling, daily schedule, one-tap labeled timers, local timer alerts, completion metadata, image annotation, Data Card export, personal inventory, inventory deduction, and scientific calculators.

**Watch out for:** Do not become a full ELN/LIMS. Timers must be persisted and notification-backed. Live Activities are a glanceable active-timer surface, not a complete scheduling backend. Recipe scaling needs strict unit discipline. Inventory deductions need transaction history and correction.

## Recommended v1 Shape

LabBuddy v1 should build one coherent local loop:

Protocol Template -> Scaled Run -> Daily Schedule -> Step Timer -> Completion Metadata -> Inventory Transaction -> Data Card

This loop supports both user goals already approved:

- Execution loop: Protocol -> automatic scaling -> Daily Schedule -> Timer -> completion record.
- Reporting loop: Protocol/metadata -> image capture and annotation -> Data Card -> shareable mentor update.

## Requirement Implications

- v1 should include the current workflow families: cell, animal, nucleic-acid, and protein experiments, with starter templates and generic structured steps rather than exhaustive domain-specific automation.
- Timer reliability and Protocol/scaling correctness are foundational and should come before polished Data Cards.
- Inventory should be local and personal with deductions and low-stock warnings, not team purchasing.
- AI features remain deferred Pro capabilities.
- iOS-only decision is reinforced by Live Activities, local notifications, App Intents, and share sheet integration.

## Source Highlights

- Apple SwiftData supports declarative local persistence and efficient model fetching, making it a strong fit for local-first app data: https://developer.apple.com/documentation/SwiftData
- Apple Live Activities appear on the Lock Screen and Dynamic Island, but have duration and payload constraints: https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities
- Apple local notifications are the correct system mechanism for alerting users when an app is backgrounded or locked: https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app
- protocols.io shows that "run protocols as checklists" is a familiar protocol execution model: https://www.protocols.io/features
- Benchling and LabArchives both reinforce the value of linking inventory usage to experiment context, but at enterprise scale; LabBuddy should adapt this locally: https://www.benchling.com/inventory and https://help.labarchives.com/hc/en-us/articles/16361218867988-Inventory-List
