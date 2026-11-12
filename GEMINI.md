# Prettier Battery — Engineering & Architecture Guide

This document defines the architectural standards, **SOLID** design principles, and **minimal resource consumption** rules for Prettier Battery. All changes must adhere to these guidelines.

---

## 1. Architecture Overview

The codebase uses a layered Objective-C / Cocoa architecture under `src/`:

```
src/
├── App/
│   ├── main.m                           # Application entry point
│   └── AppDelegate.h / .m               # Composition root & NSApplicationDelegate lifecycle
├── Models/
│   └── BatteryInfo.h / .m               # Pure battery telemetry model & localized formatting
├── Protocols/
│   └── BatteryProtocols.h               # Segregated protocols (abstractions)
├── Services/
│   ├── BatteryMonitor.h / .m            # Monitoring lifecycle & event/timer coordinator
│   ├── IOKitBatteryTelemetryProvider.*  # IOPowerSources & AppleSmartBattery reader
│   ├── SystemProfilerHealthProvider.*   # Official battery health % fetcher
│   ├── LowPowerModeController.h / .m    # macOS Low Power Mode reader/toggler
│   ├── PreferencesStore.h / .m          # NSUserDefaults display preferences
│   ├── LaunchAtLoginService.h / .m      # SMAppService login item wrapper
│   └── LocalizationManager.h / .m       # Multi-language i18n manager
└── UI/
    ├── BatteryIconRenderer.h / .m       # Pure vector NSImage icon renderer
    ├── StatusBarController.h / .m       # NSStatusItem coordinator & action handler
    ├── StatusMenuBuilder.h / .m         # NSMenu, submenus & custom header builder
    └── SystemSettingsNavigator.h / .m   # System Settings URLs & user guide alerts
```

---

## 2. SOLID Principles (Mandatory)

- **Single Responsibility (SRP)**:
  - Each class has one clear reason to change.
  - Do not mix IOKit parsing, `system_profiler` subprocesses, `NSUserDefaults` persistence, `NSMenu` construction, or `SMAppService` calls into `AppDelegate` or `BatteryMonitor`.
- **Open/Closed (OCP)**:
  - Extend behavior by adding new protocol implementations (e.g., a new `BatteryTelemetryProviding` or `BatteryIconRendering` implementation) rather than adding conditional branches to existing coordinators.
- **Liskov Substitution (LSP)**:
  - All implementations of protocols in `BatteryProtocols.h` must honor their contracts cleanly without unexpected side effects or nil-handling surprises.
- **Interface Segregation (ISP)**:
  - Keep protocols in `src/Protocols/BatteryProtocols.h` small and role-specific (`BatteryMonitoring`, `BatteryTelemetryProviding`, `BatteryHealthProviding`, `PowerModeControlling`, `PreferencesStoring`, `LaunchAtLoginControlling`, `Localizing`, `BatteryIconRendering`). Never create a monolithic "god protocol".
- **Dependency Inversion (DIP)**:
  - High-level modules (`AppDelegate`, `StatusBarController`, `StatusMenuBuilder`, `BatteryMonitor`) depend on protocol abstractions (`id<...>`), not concrete classes.
  - `AppDelegate` acts as the composition root, instantiating concrete services and injecting them via designated initializers.

---

## 3. Minimal Resource Consumption (Mandatory)

Prettier Battery runs continuously in the macOS menu bar; **zero idle CPU, minimal wakeups, and minimal memory footprint** are top priorities:

1. **Event-Driven First, Never Tight Polling**:
   - Rely on `IOPSNotificationCreateRunLoopSource` and `NSProcessInfoPowerStateDidChangeNotification` for immediate power/battery updates.
   - Any fallback `NSTimer` must use a long interval (≥ `60s`) and set `timer.tolerance` so macOS can coalesce wakeups (App Nap / energy efficiency).
2. **Avoid Redundant Redraws & Allocations**:
   - `BatteryMonitor` must only notify its delegate when relevant state (`percentage`, `state`, `isLowPowerMode`, `timeRemainingMinutes`, `healthPercentage`, `condition`) changes.
   - `StatusBarController` must diff against the last rendered state and **skip re-rendering** `NSImage` and `NSAttributedString` when nothing visible changed.
3. **On-Demand Detailed Telemetry**:
   - Instantaneous stats only shown in the dropdown (Watts, mA, Voltage, Temperature) should be fetched on demand when the menu opens (`menuNeedsUpdate:`), not continuously in the background.
4. **Minimize Subprocess Spawns**:
   - External tools like `/usr/sbin/system_profiler` are expensive; run them once at startup and infrequently thereafter (e.g., every `6 hours` with timer coalescing).
5. **Zero External Dependencies**:
   - Keep the app pure Objective-C / Cocoa / IOKit with no third-party frameworks or background daemons.

---

## 4. Build, Test & Release

- Run localization & model tests: `make test`
- Build `.app` bundle: `make build`
- Build `.dmg` installer: `make dmg`
- Releases are automated via `.github/workflows/release.yml` when pushing a `v*` tag.
- **Release Workflow Rule**: After `make test` and `make build` succeed, always commit changes, push `main` to `origin`, and create & push the next `v*` semver patch tag (e.g., `v1.0.2`).
