import Foundation

/// A thermodynamic property that can be used to specify a state.
///
/// Values are always stored in the table units:
/// p in bar, T in °C, v in m³/kg, u and h in kJ/kg, s in kJ/(kg·K), x dimensionless.
public enum Property: String, CaseIterable, Codable, Sendable, Hashable {
    case pressure = "p"
    case temperature = "T"
    case specificVolume = "v"
    case internalEnergy = "u"
    case enthalpy = "h"
    case entropy = "s"
    case quality = "x"

    public var symbol: String { rawValue }

    public var name: String {
        switch self {
        case .pressure: "Pressure"
        case .temperature: "Temperature"
        case .specificVolume: "Specific volume"
        case .internalEnergy: "Internal energy"
        case .enthalpy: "Enthalpy"
        case .entropy: "Entropy"
        case .quality: "Quality"
        }
    }

    /// The unit the value is stored in.
    public var baseUnit: String {
        switch self {
        case .pressure: "bar"
        case .temperature: "°C"
        case .specificVolume: "m³/kg"
        case .internalEnergy, .enthalpy: "kJ/kg"
        case .entropy: "kJ/(kg·K)"
        case .quality: ""
        }
    }
}

/// A property together with its value in base units.
public struct PropertyValue: Codable, Sendable, Hashable {
    public var property: Property
    public var value: Double

    public init(_ property: Property, _ value: Double) {
        self.property = property
        self.value = value
    }
}
