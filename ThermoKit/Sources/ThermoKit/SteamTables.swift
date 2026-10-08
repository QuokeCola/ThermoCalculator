import Foundation

/// Saturated liquid (f) and saturated vapor (g) properties at one point on the saturation line.
public struct SaturationPoint: Sendable, Equatable {
    public var T: Double
    public var p: Double
    public var vf: Double, vg: Double
    public var uf: Double, ug: Double
    public var hf: Double, hg: Double
    public var sf: Double, sg: Double

    public func liquid(_ property: Property) -> Double? {
        switch property {
        case .specificVolume: vf
        case .internalEnergy: uf
        case .enthalpy: hf
        case .entropy: sf
        default: nil
        }
    }

    public func vapor(_ property: Property) -> Double? {
        switch property {
        case .specificVolume: vg
        case .internalEnergy: ug
        case .enthalpy: hg
        case .entropy: sg
        default: nil
        }
    }

    static func lerp(_ a: SaturationPoint, _ b: SaturationPoint, _ t: Double) -> SaturationPoint {
        func l(_ k: KeyPath<SaturationPoint, Double>) -> Double { ThermoKit.lerp(a[keyPath: k], b[keyPath: k], t) }
        return SaturationPoint(
            T: l(\.T), p: l(\.p), vf: l(\.vf), vg: l(\.vg), uf: l(\.uf), ug: l(\.ug),
            hf: l(\.hf), hg: l(\.hg), sf: l(\.sf), sg: l(\.sg))
    }
}

/// One point of the superheated vapor table.
struct SuperheatedPoint: Sendable {
    var T: Double
    var v: Double, u: Double, h: Double, s: Double
}

/// One isobar (constant-pressure sub-table) of the superheated vapor table.
struct Isobar: Sendable {
    var p: Double
    /// Saturation temperature, nil above the critical pressure.
    var Tsat: Double?
    /// Points in ascending T; when `Tsat` is set the first point is the saturated vapor state.
    var points: [SuperheatedPoint]
    var temperatures: [Double]

    var maxT: Double { temperatures.last ?? -.infinity }
    var minT: Double { temperatures.first ?? .infinity }

    /// Linear interpolation in T. Returns nil outside the tabulated range.
    func at(T: Double) -> SuperheatedPoint? {
        guard let (i, t) = temperatures.bracket(T) else { return nil }
        if t == 0 { return points[i] }
        let a = points[i], b = points[i + 1]
        return SuperheatedPoint(T: T, v: lerp(a.v, b.v, t), u: lerp(a.u, b.u, t), h: lerp(a.h, b.h, t), s: lerp(a.s, b.s, t))
    }
}

/// Steam tables for water (Moran & Shapiro, SI Tables A-2, A-3 and A-4).
public struct SteamTables: Sendable {
    /// Table A-2, ascending in T.
    public let byTemperature: [SaturationPoint]
    /// Table A-3, ascending in p.
    public let byPressure: [SaturationPoint]
    let isobars: [Isobar]

    private let a2T: [Double]
    private let a2p: [Double]
    private let a3p: [Double]
    private let isobarPressures: [Double]

    public var criticalPoint: SaturationPoint { byTemperature.last! }
    public var triplePoint: SaturationPoint { byTemperature.first! }
    public var minimumSuperheatedPressure: Double { isobarPressures.first! }
    public var maximumPressure: Double { isobarPressures.last! }
    public var maximumTemperature: Double { isobars.map(\.maxT).max()! }

    /// The tables bundled with ThermoKit.
    public static let water: SteamTables = {
        func load(_ name: String) -> String {
            guard let url = Bundle.module.url(forResource: name, withExtension: "csv", subdirectory: "steam"),
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else { fatalError("ThermoKit: missing bundled table \(name).csv") }
            return text
        }
        do {
            return try SteamTables(
                saturatedByTemperatureCSV: load("saturated_by_temperature"),
                saturatedByPressureCSV: load("saturated_by_pressure"),
                superheatedCSV: load("superheated"))
        } catch {
            fatalError("ThermoKit: bundled tables are invalid: \(error)")
        }
    }()

    public struct FormatError: Error, CustomStringConvertible {
        public var description: String
    }

    /// Builds the tables from CSV text in the format written by the data repository's `build_tables.py`.
    public init(saturatedByTemperatureCSV: String, saturatedByPressureCSV: String, superheatedCSV: String) throws {
        func saturation(_ csv: String, keyFirst: String) throws -> [SaturationPoint] {
            try CSV.rows(csv, required: [keyFirst, "T", "p", "vf", "vg", "uf", "ug", "hf", "hg", "sf", "sg"]).map { r in
                SaturationPoint(T: r["T"]!, p: r["p"]!, vf: r["vf"]!, vg: r["vg"]!, uf: r["uf"]!, ug: r["ug"]!,
                                hf: r["hf"]!, hg: r["hg"]!, sf: r["sf"]!, sg: r["sg"]!)
            }
        }
        byTemperature = try saturation(saturatedByTemperatureCSV, keyFirst: "T")
        byPressure = try saturation(saturatedByPressureCSV, keyFirst: "p")

        var grouped: [Double: Isobar] = [:]
        for r in try CSV.rows(superheatedCSV, required: ["p", "T", "saturated", "v", "u", "h", "s"]) {
            let p = r["p"]!
            var isobar = grouped[p] ?? Isobar(p: p, Tsat: nil, points: [], temperatures: [])
            if r["saturated"]! == 1 { isobar.Tsat = r["T"]! }
            isobar.points.append(SuperheatedPoint(T: r["T"]!, v: r["v"]!, u: r["u"]!, h: r["h"]!, s: r["s"]!))
            grouped[p] = isobar
        }
        isobars = grouped.values.map { iso in
            var iso = iso
            iso.points.sort { $0.T < $1.T }
            iso.temperatures = iso.points.map(\.T)
            return iso
        }.sorted { $0.p < $1.p }

        a2T = byTemperature.map(\.T)
        a2p = byTemperature.map(\.p)
        a3p = byPressure.map(\.p)
        isobarPressures = isobars.map(\.p)

        for (name, values) in [("A-2 T", a2T), ("A-2 p", a2p), ("A-3 p", a3p), ("A-4 p", isobarPressures)] {
            guard values.count >= 2, zip(values, values.dropFirst()).allSatisfy({ $0 < $1 }) else {
                throw FormatError(description: "\(name) column must be strictly increasing")
            }
        }
    }

    // MARK: Saturation

    /// Saturation properties at temperature `T` (°C), from Table A-2.
    public func saturation(atTemperature T: Double) -> SaturationPoint? {
        guard let (i, t) = a2T.bracket(T) else { return nil }
        return t == 0 ? byTemperature[i] : .lerp(byTemperature[i], byTemperature[i + 1], t)
    }

    /// Saturation properties at pressure `p` (bar), from Table A-3,
    /// falling back to Table A-2 below the first A-3 pressure.
    public func saturation(atPressure p: Double) -> SaturationPoint? {
        if let (i, t) = a3p.bracket(p) {
            return t == 0 ? byPressure[i] : .lerp(byPressure[i], byPressure[i + 1], t)
        }
        guard let (i, t) = a2p.bracket(p) else { return nil }
        return t == 0 ? byTemperature[i] : .lerp(byTemperature[i], byTemperature[i + 1], t)
    }

    // MARK: Superheated vapor

    /// The pair of isobars surrounding `p` and the interpolation weight in log(p).
    func isobars(around p: Double) -> (Isobar, Isobar, Double)? {
        guard let (i, _) = isobarPressures.bracket(p) else { return nil }
        let a = isobars[i]
        guard i + 1 < isobars.count, p != a.p else { return (a, a, 0) }
        let b = isobars[i + 1]
        return (a, b, log(p / a.p) / log(b.p / a.p))
    }
}

/// Minimal CSV reader for the numeric tables.
enum CSV {
    static func rows(_ text: String, required: [String]) throws -> [[String: Double]] {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let headerLine = lines.first else { throw SteamTables.FormatError(description: "empty table") }
        let header = headerLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for column in required where !header.contains(column) {
            throw SteamTables.FormatError(description: "missing column \(column)")
        }
        return try lines.dropFirst().map { line in
            let cells = line.split(separator: ",", omittingEmptySubsequences: false)
            guard cells.count == header.count else {
                throw SteamTables.FormatError(description: "wrong number of cells in “\(line)”")
            }
            var row: [String: Double] = [:]
            for (name, cell) in zip(header, cells) {
                guard let value = Double(cell.trimmingCharacters(in: .whitespaces)) else {
                    throw SteamTables.FormatError(description: "not a number: “\(cell)” in “\(line)”")
                }
                row[name] = value
            }
            return row
        }
    }
}
