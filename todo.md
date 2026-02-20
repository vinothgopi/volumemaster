# VolumeMaster — Review Findings

## Critical

- [ ] **Save previous output UID after aggregate creation, not before**
  `AggregateDeviceManager.swift:64-66` — If creation fails, the saved UID is orphaned and `revertDefaultOutput()` could switch to the wrong device. Move the save to after the `guard status == noErr` check.

- [ ] **No UI feedback when accessibility permission is denied**
  `MediaKeyInterceptor.swift:85-93` — Media keys silently stop working. The user has no idea why. Surface a warning in the merge status or settings UI when `AXIsProcessTrusted()` is false and merge is active.

- [ ] **`mergeError` never cleared on disable**
  `SettingsViewModel.swift:41-46` — Toggling merge off doesn't clear `mergeError`. Stale error message stays visible.

## Moderate

- [ ] **Triple device enumeration in `refresh()`**
  `MenuBarViewModel.swift:19-24`, `SettingsViewModel.swift:17-23` — Each call to `outputDevices()`, `inputDevices()`, etc. queries CoreAudio's full device list independently. Query once and derive the rest.

- [ ] **`activeProfileName` persists after manual device change**
  `MenuBarViewModel.swift` — Profile badge stays visible even after the user manually switches devices. Should clear on manual selection via `selectOutputDevice`/`selectInputDevice`.

- [ ] **WindowTracker polls every 0.5s**
  `WindowTracker.swift:16` — Continuous timer while spatial audio is active. Consider event-driven approach with `AXObserver` for window move events.

- [ ] **No validation that primary != secondary in merge config**
  `AppSettings.swift` — `hasMergeDevicesConfigured` only checks non-empty. Should also check that the two UIDs differ.

## Minor

- [ ] **Silent `try?` throughout profile application**
  `MenuBarViewModel.swift:107,110` — Failures setting default devices are swallowed. At minimum log on failure.

- [ ] **`applyProfile` sets name even if profile is a no-op**
  `MenuBarViewModel.swift:96` — Sets `activeProfileName` immediately even if all optional fields are nil and nothing actually changes.

- [ ] **`DeviceMonitor.stopMonitoring()` not called on app termination**
  `AppDelegate.swift` — Aggregate cleanup is done but the device listener isn't explicitly removed. Harmless since the process is exiting, but inconsistent.
