# Thermo Calculator

An iOS app that finds the full thermodynamic state of water from any two properties.
Type something like `p = 1 bar, v = 0.012 m^3/kg` and it reports the phase and
p, T, v, u, h, s (and quality x in the two-phase region), using linear interpolation
in the textbook steam tables (Moran & Shapiro, SI Tables A-2, A-3 and A-4).

Version 2 is a rewrite of the original 2020 UIKit app in SwiftUI. The 2020 code is in
the git history (last commit before the rewrite: `869d96f`).

## Layout

| Path | What it is |
| --- | --- |
| `ThermoKit/` | Swift package with the tables, the input parser and the solver. No UI; builds and tests on macOS and Linux. |
| `App/` | SwiftUI app (iOS 17+, iPhone and iPad). `ThermoCalc.xcodeproj` is generated from `project.yml`. |
| `.github/workflows/ci.yml` | Runs the ThermoKit tests on Linux and macOS and builds the app for the iOS Simulator. |

The tables come from [mobileapp_thermcalc_data](https://github.com/QuokeCola/mobileapp_thermcalc_data),
whose `build_tables.py` cleans and checks them. To refresh the copies bundled in ThermoKit:

```sh
ThermoKit/Scripts/update-tables.sh ../mobileapp_thermcalc_data
```

## Building

- **App:** open `App/ThermoCalc.xcodeproj` in Xcode 16 or later, pick your team under
  Signing & Capabilities, and run. After changing `App/project.yml`, regenerate the project
  with `brew install xcodegen && cd App && xcodegen`.
- **Engine only:** `cd ThermoKit && swift test`.

## Input

Any two different properties, separated by a comma or semicolon:

| Property | Symbol | Units accepted (default first) |
| --- | --- | --- |
| Pressure | `p` | bar, Pa, kPa, MPa, atm, psi |
| Temperature | `T` | °C (`C`), K, °F |
| Specific volume | `v` | m³/kg (`m^3/kg`), L/kg |
| Internal energy | `u` | kJ/kg, J/kg, BTU/lb |
| Enthalpy | `h` | kJ/kg, J/kg, BTU/lb |
| Entropy | `s` | kJ/(kg·K), J/(kg·K) |
| Quality | `x` | fraction or % |

## How the solver works

- **Two-phase:** with p or T given, a value between the saturated liquid and vapor values
  gives the quality directly.
- **Superheated vapor / supercritical:** linear in T within a pressure sub-table. Between
  sub-tables values are interpolated in log p (and v as log v), because linear-in-p
  interpolation is badly off across the widely spaced low-pressure tables
  (at 0.2 bar, 200 °C it gives v ≈ 26 m³/kg instead of 10.9). Subcritical sub-tables are
  compared at equal superheat T − Tsat.
- **Compressed liquid:** there is no Table A-5 yet, so it uses the saturated liquid at the
  same T, with h ≈ hf + vf·(p − psat). These results are marked as approximate.
- **Below 0.06 bar** (the lowest superheated table) vapor is treated as an ideal gas,
  also marked as approximate.
- Pairs without p or T (for example h and s) are solved numerically over pressure.

## Not done yet

- Other substances from the original picker (air, nitrogen, R-22, R-134a, ammonia, propane)
  need their tables converted first.
- Table A-5 (compressed liquid) would replace the approximation above.
- App Store release.
