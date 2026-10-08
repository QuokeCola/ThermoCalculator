import Foundation

/// Conversions between user-facing units and the base units in `Property.baseUnit`.
public enum Units {
    /// Converts `value`, written in `unit`, to the base unit of `property`.
    /// An empty unit means the value is already in base units.
    /// Returns nil when the unit is not recognised for that property.
    public static func toBase(_ value: Double, unit: String, for property: Property) -> Double? {
        let key = normalize(unit)
        if key.isEmpty { return value }
        switch property {
        case .pressure:
            return pressureFactors[key].map { value * $0 }
        case .temperature:
            switch key {
            case "c", "degc": return value
            case "k": return value - 273.15
            case "f", "degf": return (value - 32) * 5 / 9
            case "r", "degr": return (value - 491.67) * 5 / 9
            default: return nil
            }
        case .specificVolume:
            return volumeFactors[key].map { value * $0 }
        case .internalEnergy, .enthalpy:
            return energyFactors[key].map { value * $0 }
        case .entropy:
            return entropyFactors[key].map { value * $0 }
        case .quality:
            return key == "%" ? value / 100 : nil
        }
    }

    /// Lowercases and strips decoration so "kJ/(kg·K)", "kj/kg-k" and "kJ/kgK" compare equal.
    static func normalize(_ unit: String) -> String {
        var s = unit.lowercased()
        s = s.replacingOccurrences(of: "³", with: "3")
        s = s.replacingOccurrences(of: "°", with: "deg")
        for junk in [" ", "^", "·", "*", "(", ")", "-", "⋅", "."] {
            s = s.replacingOccurrences(of: junk, with: "")
        }
        // "kj/kg/k" -> "kj/kgk"
        if s.hasSuffix("/k"), s.filter({ $0 == "/" }).count == 2 {
            s = String(s.dropLast(2)) + "k"
        }
        return s
    }

    private static let pressureFactors: [String: Double] = [
        "bar": 1, "mbar": 1e-3, "pa": 1e-5, "kpa": 1e-2, "mpa": 10,
        "atm": 1.01325, "psi": 0.0689475729, "psia": 0.0689475729,
    ]
    private static let volumeFactors: [String: Double] = [
        "m3/kg": 1, "l/kg": 1e-3, "cm3/g": 1e-3, "ml/g": 1e-3, "ft3/lb": 0.0624279606, "ft3/lbm": 0.0624279606,
    ]
    private static let energyFactors: [String: Double] = [
        "kj/kg": 1, "j/kg": 1e-3, "mj/kg": 1e3, "j/g": 1, "btu/lb": 2.326, "btu/lbm": 2.326,
    ]
    private static let entropyFactors: [String: Double] = [
        "kj/kgk": 1, "j/kgk": 1e-3, "kj/kgdegc": 1, "j/gk": 1,
        "btu/lbr": 4.1868, "btu/lbmr": 4.1868, "btu/lbdegr": 4.1868, "btu/lbmdegr": 4.1868,
    ]
}

/// Display units the app can show results in.
public enum PressureUnit: String, CaseIterable, Codable, Sendable {
    case bar, kPa, MPa

    public func fromBar(_ bar: Double) -> Double {
        switch self {
        case .bar: bar
        case .kPa: bar * 100
        case .MPa: bar / 10
        }
    }
}

public enum TemperatureUnit: String, CaseIterable, Codable, Sendable {
    case celsius = "°C"
    case kelvin = "K"

    public func fromCelsius(_ c: Double) -> Double {
        switch self {
        case .celsius: c
        case .kelvin: c + 273.15
        }
    }
}
