import Foundation

public enum ThermoError: Error, Equatable, CustomStringConvertible {
    /// Both inputs are the same property.
    case sameProperty(Property)
    /// The value cannot describe any state (negative volume, quality outside 0…1, …).
    case invalidValue(Property)
    /// The state lies outside the range the tables cover.
    case outOfRange
    /// p and T lie on the saturation line, which leaves the quality undetermined.
    case onSaturationLine
    /// The state is compressed liquid, where v, u, h and s barely depend on pressure, so T plus one of them cannot fix p.
    case compressedLiquidNeedsPressure(Property)
    /// Quality was given for a state above the critical point.
    case qualityAboveCriticalPoint
    /// The solver did not find a state with these two values.
    case noSolution

    public var description: String {
        switch self {
        case .sameProperty(let p): "Both inputs are \(p.name.lowercased()); enter two different properties."
        case .invalidValue(let p): "That \(p.name.lowercased()) is not physically possible."
        case .outOfRange: "That state is outside the range the steam tables cover."
        case .onSaturationLine: "p and T are on the saturation line, which leaves the state undetermined. Give the quality x or another property instead."
        case .compressedLiquidNeedsPressure: "This is compressed liquid, where properties depend almost only on temperature, so the tables cannot fix the pressure. Give the pressure as well."
        case .qualityAboveCriticalPoint: "Quality only exists below the critical point (220.9 bar, 374.14 °C)."
        case .noSolution: "No state matches both values."
        }
    }
}

/// Finds the full thermodynamic state of water from any two independent properties,
/// by linear interpolation in the steam tables.
public struct ThermoSolver: Sendable {
    public let tables: SteamTables

    /// Gas constant of water vapor, kJ/(kg·K).
    static let R = 0.4615

    public init(tables: SteamTables = .water) {
        self.tables = tables
    }

    /// Parses `text` (for example `p=1bar, v=0.012m^3/kg`) and solves for the state.
    public func state(for text: String) throws -> ThermoState {
        let (a, b) = try InputParser.parse(text)
        return try state(a, b)
    }

    public func state(_ a: PropertyValue, _ b: PropertyValue) throws(ThermoError) -> ThermoState {
        guard a.property != b.property else { throw .sameProperty(a.property) }
        for item in [a, b] { try validate(item) }

        var given: [Property: Double] = [:]
        given[a.property] = a.value
        given[b.property] = b.value
        let others = [a, b].filter { $0.property != .pressure && $0.property != .temperature && $0.property != .quality }

        switch (given[.pressure], given[.temperature], given[.quality]) {
        case let (p?, T?, nil):
            return try state(p: p, T: T)
        case let (p?, nil, x?):
            guard p <= critical.p else { throw .qualityAboveCriticalPoint }
            guard let sat = tables.saturation(atPressure: p) else { throw .outOfRange }
            return mixture(sat, x: x)
        case let (nil, T?, x?):
            guard T <= critical.T else { throw .qualityAboveCriticalPoint }
            guard let sat = tables.saturation(atTemperature: T) else { throw .outOfRange }
            return mixture(sat, x: x)
        case let (p?, nil, nil):
            return try state(p: p, other: others[0])
        case let (nil, T?, nil):
            return try state(T: T, other: others[0])
        case let (nil, nil, x?):
            return try state(x: x, other: others[0])
        case (nil, nil, nil):
            return try state(neither: others[0], others[1])
        default:
            throw .noSolution
        }
    }

    private var critical: SaturationPoint { tables.criticalPoint }

    private func validate(_ item: PropertyValue) throws(ThermoError) {
        let v = item.value
        guard v.isFinite else { throw .invalidValue(item.property) }
        switch item.property {
        case .pressure, .specificVolume:
            guard v > 0 else { throw .invalidValue(item.property) }
        case .temperature:
            guard v > -273.15 else { throw .invalidValue(item.property) }
        case .quality:
            guard (0...1).contains(v) else { throw .invalidValue(item.property) }
        case .internalEnergy, .enthalpy, .entropy:
            break
        }
    }

    // MARK: Pressure and temperature

    /// The single-phase state at pressure `p` (bar) and temperature `T` (°C).
    public func state(p: Double, T: Double) throws(ThermoError) -> ThermoState {
        guard p >= tables.triplePoint.p, p <= tables.maximumPressure,
              T >= tables.triplePoint.T, T <= tables.maximumTemperature
        else { throw .outOfRange }

        if p > critical.p {
            return T < critical.T ? try compressedLiquid(p: p, T: T) : try superheated(p: p, T: T)
        }
        guard let sat = tables.saturation(atPressure: p) else { throw .outOfRange }
        if abs(T - sat.T) < 1e-9 { throw .onSaturationLine }
        return T < sat.T ? try compressedLiquid(p: p, T: T) : try superheated(p: p, T: T)
    }

    /// Compressed liquid approximated from saturated liquid at the same temperature,
    /// with the pressure correction h ≈ hf(T) + vf(T)·(p − psat(T)).
    func compressedLiquid(p: Double, T: Double) throws(ThermoError) -> ThermoState {
        guard let sat = tables.saturation(atTemperature: T) else { throw .outOfRange }
        let h = sat.hf + sat.vf * (p - sat.p) * 100
        return ThermoState(phase: .compressedLiquid, p: p, T: T, v: sat.vf, u: sat.uf, h: h, s: sat.sf,
                           x: nil, isApproximate: true)
    }

    /// Superheated vapor (or supercritical fluid) from Table A-4.
    ///
    /// Within an isobar values are linear in T. Between isobars they are interpolated in log(p)
    /// (v as log v), which follows the near-ideal-gas behaviour far better than linear-in-p
    /// across the widely spaced low-pressure sub-tables. Below the saturation temperature
    /// the subcritical isobars are compared at equal superheat T − Tsat.
    func superheated(p: Double, T: Double) throws(ThermoError) -> ThermoState {
        let phase: Phase = (p > critical.p && T >= critical.T) ? .supercriticalFluid : .superheatedVapor

        if p < tables.minimumSuperheatedPressure {
            // Ideal gas below the lowest tabulated pressure: u and h depend on T only.
            let iso = tables.isobars[0]
            guard let point = iso.at(T: T) ?? extrapolateBelow(iso, T: T) else { throw .outOfRange }
            return ThermoState(phase: phase, p: p, T: T, v: point.v * iso.p / p, u: point.u, h: point.h,
                               s: point.s - Self.R * log(p / iso.p), x: nil, isApproximate: true)
        }

        guard let (a, b, w) = tables.isobars(around: p) else { throw .outOfRange }
        let pa: SuperheatedPoint?
        let pb: SuperheatedPoint?
        if let ta = a.Tsat, let tb = b.Tsat {
            let superheat = T - lerp(ta, tb, w)
            guard superheat > -1 else { throw .outOfRange }
            pa = a.at(T: ta + max(superheat, 0))
            pb = b.at(T: tb + max(superheat, 0))
        } else {
            pa = a.at(T: T)
            pb = b.at(T: T)
        }
        guard let pa, let pb else { throw .outOfRange }
        return ThermoState(
            phase: phase, p: p, T: T,
            v: exp(lerp(log(pa.v), log(pb.v), w)),
            u: lerp(pa.u, pb.u, w), h: lerp(pa.h, pb.h, w), s: lerp(pa.s, pb.s, w),
            x: nil, isApproximate: false)
    }

    private func extrapolateBelow(_ iso: Isobar, T: Double) -> SuperheatedPoint? {
        guard T < iso.minT, iso.points.count >= 2 else { return nil }
        let a = iso.points[0], b = iso.points[1]
        let t = (T - a.T) / (b.T - a.T)
        return SuperheatedPoint(T: T, v: lerp(a.v, b.v, t), u: lerp(a.u, b.u, t), h: lerp(a.h, b.h, t), s: lerp(a.s, b.s, t))
    }

    func mixture(_ sat: SaturationPoint, x: Double) -> ThermoState {
        let phase: Phase = x == 0 ? .saturatedLiquid : x == 1 ? .saturatedVapor : .saturatedMixture
        return ThermoState(
            phase: phase, p: sat.p, T: sat.T,
            v: lerp(sat.vf, sat.vg, x), u: lerp(sat.uf, sat.ug, x),
            h: lerp(sat.hf, sat.hg, x), s: lerp(sat.sf, sat.sg, x),
            x: x, isApproximate: false)
    }

    /// Quality from a two-phase property value, or nil when the value is outside the dome.
    private func quality(_ sat: SaturationPoint, _ other: PropertyValue) -> Double? {
        guard let f = sat.liquid(other.property), let g = sat.vapor(other.property),
              other.value >= f, other.value <= g, g > f
        else { return nil }
        return (other.value - f) / (g - f)
    }

    // MARK: One of p, T plus another property

    func state(p: Double, other: PropertyValue) throws(ThermoError) -> ThermoState {
        guard p >= tables.triplePoint.p, p <= tables.maximumPressure else { throw .outOfRange }
        if p <= critical.p, let sat = tables.saturation(atPressure: p), let x = quality(sat, other) {
            return mixture(sat, x: x)
        }
        let range = tables.triplePoint.T...tables.maximumTemperature
        let found = solveRoot(in: range, samples: 240) { T in
            try residual(self.state(p: p, T: T), other)
        }
        guard let T = found else { throw .outOfRange }
        return try verified(state(p: p, T: T), other)
    }

    func state(T: Double, other: PropertyValue) throws(ThermoError) -> ThermoState {
        guard T >= tables.triplePoint.T, T <= tables.maximumTemperature else { throw .outOfRange }
        if T < critical.T, let sat = tables.saturation(atTemperature: T) {
            if let x = quality(sat, other) { return mixture(sat, x: x) }
            if let f = sat.liquid(other.property), other.value < f {
                throw .compressedLiquidNeedsPressure(other.property)
            }
        }
        let range = tables.triplePoint.p...tables.maximumPressure
        let found = solveRoot(in: range, samples: 240, logarithmic: true) { p in
            try residual(self.state(p: p, T: T), other)
        }
        guard let p = found else { throw .outOfRange }
        return try verified(state(p: p, T: T), other)
    }

    // MARK: Neither p nor T

    func state(x: Double, other: PropertyValue) throws(ThermoError) -> ThermoState {
        let range = tables.triplePoint.p...critical.p
        let found = solveRoot(in: range, logarithmic: true) { p in
            guard let sat = self.tables.saturation(atPressure: p) else { throw ThermoError.outOfRange }
            return try residual(self.mixture(sat, x: x), other)
        }
        guard let p = found, let sat = tables.saturation(atPressure: p) else { throw .noSolution }
        return try verified(mixture(sat, x: x), other)
    }

    func state(neither first: PropertyValue, _ second: PropertyValue) throws(ThermoError) -> ThermoState {
        let range = tables.triplePoint.p...tables.maximumPressure
        let found = solveRoot(in: range, samples: 120, logarithmic: true) { p in
            try residual(self.state(p: p, other: first), second)
        }
        guard let p = found else { throw .noSolution }
        return try verified(state(p: p, other: first), second)
    }

    // MARK: Helpers

    private func residual(_ state: ThermoState, _ target: PropertyValue) throws -> Double {
        guard let value = state.value(of: target.property) else { throw ThermoError.noSolution }
        return value - target.value
    }

    /// Rejects a root that bisection found across a discontinuity rather than at a real solution.
    private func verified(_ state: ThermoState, _ target: PropertyValue) throws(ThermoError) -> ThermoState {
        guard let value = state.value(of: target.property) else { throw .noSolution }
        guard abs(value - target.value) <= 1e-6 * max(1, abs(target.value)) else { throw .noSolution }
        return state
    }

}
