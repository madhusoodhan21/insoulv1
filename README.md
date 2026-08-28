# InSoul — Flutter App (Stitch UI pass)

Flutter build of InSoul, restyled to match the **Stitch "InSoul Gait
Analysis"** design (dark navy / teal, Public Sans + Space Grotesk), with
all existing BLE logic carried over untouched, plus a new live
**Accelerometer** screen for the MPU6050.

## Setup (VS Code)

1. `flutter pub get`
2. Run on a physical phone/desktop with Bluetooth for BLE
   (`flutter run` → pick your device). BLE doesn't work on
   emulators/simulators.
3. Android BLE permissions / iOS Bluetooth usage descriptions were already
   merged in a previous pass — nothing to do there.

## What changed in this pass (Stitch UI + accelerometer)

**Visuals — every screen restyled to match the Stitch mockups:**
- `app_theme.dart` — new color tokens (deep navy `#051424` bg, teal
  `#2DD4BF`/`#57F1DB` primary) and fonts (Space Grotesk for big metrics,
  Public Sans for everything else), taken directly from the Stitch
  `DESIGN.md`. Old color/font names (`AppColors.yellow`, `AppFonts.dot`,
  etc.) are kept as aliases so `calibration_screen.dart` and
  `diagnostics_screen.dart` — the two screens **not** covered by the new
  Stitch export — still compile and now pick up the new palette for free.
- `scan_screen.dart` → **Connect Shoe** screen: logo badge (your
  `insoul_logo.png`, now bundled as an asset), pulsing Bluetooth target,
  pill "SCAN DEVICES" button, device list. **BLE scanning/connecting logic
  is unchanged** — only the UI around it.
- `home_screen.dart` → **Dashboard**: greeting header, connect status
  pill, big steps ring card, gait symmetry bar, metric cards. Step ring
  still shows live ESP32 data the same way it did before.
- `exercise_screen.dart` → **Daily Protocol** cards (prescribed / done),
  tapping "Start" opens the same countdown-timer logic as before, now in a
  bottom sheet.
- `physio_screen.dart` → toggles between **Physio Analysis** (live
  pressure map, current pattern, stride length, session log) and **Weekly
  Insights** (steps/distance/gait/pressure tabs with a simple bar chart) —
  both Stitch mockups live under the one "Physio" tab.
- `profile_screen.dart` → avatar header, Daily Step Goal card (now
  editable), Hardware Status card, Preferences list. All previous
  functionality (notifications toggle, privacy dialog, sign-out +
  disconnect, calibration/diagnostics links) is preserved.
- `app_shell.dart` → bottom nav restyled (active tab gets a teal pill), and
  the FAB now opens a **Create New Activity** sheet (activity type,
  duration slider, goal callout) matching the Stitch mockup, replacing the
  old plain "Log Activity" sheet.
- `metric_card.dart` → restyled to the design's 24px-radius "Data Card"
  spec.

**New — Accelerometer screen (your request):**
- `accelerometer_screen.dart` is new, linked from **Profile → Accelerometer
  (MPU6050)**. It shows live X/Y/Z accelerometer (g) and gyroscope (°/s)
  values plus packet count / last-packet age.
- No new BLE plumbing was needed — `ble_service.dart` already parsed
  `ax/ay/az/gx/gy/gz` out of the ESP32's IMU JSON packet in an earlier
  pass (see `_updateStepCountFromBytes`); this screen just displays those
  existing fields live via the same `Provider<BleService>` the rest of the
  app already uses. If your current `smart_gait_esp32.ino` firmware isn't
  yet sending an `"imu": {"ax":…}` object in its JSON payload, the screen
  will show a note asking for that field — the app side is ready for it.

## Screen map

| Screen | File | Status |
|---|---|---|
| Connect Shoe | `scan_screen.dart` | Real BLE scan/connect, Stitch visuals |
| Dashboard (Home) | `home_screen.dart` | Live step ring; other metrics still placeholder |
| Daily Protocol (Exercise) | `exercise_screen.dart` | Clickable, working countdown timer |
| Physio Analysis / Weekly Insights | `physio_screen.dart` | Clickable UI shells — pressure/stride numbers still placeholder |
| Profile | `profile_screen.dart` | Editable step goal, working toggles/dialogs |
| **Accelerometer (new)** | `accelerometer_screen.dart` | **Live MPU6050 data from BLE** |
| Calibration / Diagnostics | `calibration_screen.dart` / `diagnostics_screen.dart` | Unchanged from previous pass (not in the Stitch export) |

## Still placeholder / demo data

Gait symmetry %, distance, wear time, stride length, pressure-map colors,
session log rows, and the weekly bar chart are all static/demo values —
same as before this pass. Only step count and the new accelerometer/
gyroscope readings are wired to real ESP32 data.

## Fonts & assets

Public Sans + Space Grotesk via `google_fonts` (no manual font files).
`assets/images/insoul_logo.png` is bundled and registered in
`pubspec.yaml`.
