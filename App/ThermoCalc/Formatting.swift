import Foundation
import ThermoKit

/// One displayed property of a state.
struct PropertyRow: Identifiable {
    var property: Property
    var value: String
    var unit: String

    var id: Property { property }
    var valueWithUnit: String { unit.isEmpty ? value : "\(value) \(unit)" }
}

enum Format {
    /// Formats with up to five significant digits, the precision of the tables.
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.significantDigits(1...5)).grouping(.never))
    }

    static func rows(for state: ThermoState, pressure: PressureUnit, temperature: TemperatureUnit) -> [PropertyRow] {
        var rows = [
            PropertyRow(property: .pressure, value: number(pressure.fromBar(state.p)), unit: pressure.rawValue),
            PropertyRow(property: .temperature, value: number(temperature.fromCelsius(state.T)), unit: temperature.rawValue),
            PropertyRow(property: .specificVolume, value: number(state.v), unit: Property.specificVolume.baseUnit),
            PropertyRow(property: .internalEnergy, value: number(state.u), unit: Property.internalEnergy.baseUnit),
            PropertyRow(property: .enthalpy, value: number(state.h), unit: Property.enthalpy.baseUnit),
            PropertyRow(property: .entropy, value: number(state.s), unit: Property.entropy.baseUnit),
        ]
        if let x = state.x {
            rows.append(PropertyRow(property: .quality, value: number(x), unit: ""))
        }
        return rows
    }

    static func summary(for state: ThermoState, pressure: PressureUnit, temperature: TemperatureUnit) -> String {
        let lines = rows(for: state, pressure: pressure, temperature: temperature)
            .map { "\($0.property.symbol) = \($0.valueWithUnit)" }
        return ([state.phase.name] + lines).joined(separator: "\n")
    }
}
