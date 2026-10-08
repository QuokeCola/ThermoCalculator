import Foundation

public enum Phase: String, Codable, Sendable {
    case compressedLiquid
    case saturatedLiquid
    case saturatedMixture
    case saturatedVapor
    case superheatedVapor
    case supercriticalFluid

    public var name: String {
        switch self {
        case .compressedLiquid: "Compressed liquid"
        case .saturatedLiquid: "Saturated liquid"
        case .saturatedMixture: "Saturated liquid–vapor mixture"
        case .saturatedVapor: "Saturated vapor"
        case .superheatedVapor: "Superheated vapor"
        case .supercriticalFluid: "Supercritical fluid"
        }
    }
}

/// A fully determined state, in table units (bar, °C, m³/kg, kJ/kg, kJ/(kg·K)).
public struct ThermoState: Codable, Sendable, Hashable {
    public var phase: Phase
    public var p: Double
    public var T: Double
    public var v: Double
    public var u: Double
    public var h: Double
    public var s: Double
    /// Vapor mass fraction; nil outside the two-phase region.
    public var x: Double?
    /// True when the state comes from an approximation instead of table interpolation
    /// (compressed liquid from saturated liquid data, or ideal-gas behaviour below the lowest superheated pressure).
    public var isApproximate: Bool

    public func value(of property: Property) -> Double? {
        switch property {
        case .pressure: p
        case .temperature: T
        case .specificVolume: v
        case .internalEnergy: u
        case .enthalpy: h
        case .entropy: s
        case .quality: x
        }
    }
}
