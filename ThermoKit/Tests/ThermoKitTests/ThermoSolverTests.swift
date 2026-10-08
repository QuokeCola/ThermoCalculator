import Testing
@testable import ThermoKit

private let solver = ThermoSolver()

private func solve(_ text: String) throws -> ThermoState {
    try solver.state(for: text)
}

private func close(_ a: Double?, _ b: Double, rel: Double = 1e-4, abs tol: Double = 1e-9) -> Bool {
    guard let a else { return false }
    return Swift.abs(a - b) <= max(tol, rel * Swift.abs(b))
}

@Suite("Tables")
struct TableTests {
    @Test func bundledTablesLoad() {
        let t = SteamTables.water
        #expect(t.byTemperature.count == 70)
        #expect(t.byPressure.count == 50)
        #expect(t.isobars.count == 24)
        #expect(t.criticalPoint.p == 220.9)
        #expect(t.criticalPoint.T == 374.14)
        #expect(t.maximumPressure == 320)
    }

    @Test func saturationLookupMatchesTableRows() throws {
        let sat = try #require(SteamTables.water.saturation(atTemperature: 100))
        #expect(sat.p == 1.014)
        #expect(sat.vf == 1.0435e-3)
        #expect(sat.hg == 2676.1)
        let byP = try #require(SteamTables.water.saturation(atPressure: 10))
        #expect(byP.T == 179.9)
        #expect(byP.sg == 6.5863)
    }

    @Test func saturationInterpolatesLinearly() throws {
        let sat = try #require(SteamTables.water.saturation(atTemperature: 102.5))
        #expect(close(sat.hg, 2676.1 + 0.25 * (2691.5 - 2676.1)))
    }
}

@Suite("Solver")
struct SolverTests {
    @Test func superheatedTablePoint() throws {
        let s = try solve("p=10bar, T=280C")
        #expect(s.phase == .superheatedVapor)
        #expect(close(s.v, 0.2480))
        #expect(close(s.u, 2760.2))
        #expect(close(s.h, 3008.2))
        #expect(close(s.s, 7.0465))
        #expect(!s.isApproximate)
    }

    @Test func superheatedInterpolatesInTemperature() throws {
        let s = try solve("p=1MPa, T=300")
        #expect(close(s.v, (0.2480 + 0.2678) / 2))
        #expect(close(s.h, (3008.2 + 3093.9) / 2))
    }

    @Test func superheatedBetweenIsobarsIsCloseToReference() throws {
        // Reference (IAPWS-IF97): 12 bar, 300 °C → v = 0.2138 m³/kg, h = 3046.9 kJ/kg, s = 7.0335 kJ/kg·K.
        let s = try solve("p=12bar, T=300C")
        #expect(close(s.v, 0.2138, rel: 0.01))
        #expect(close(s.h, 3046.9, rel: 0.002))
        #expect(close(s.s, 7.0335, rel: 0.002))
    }

    @Test func lowPressureSuperheatedUsesLogInterpolation() throws {
        // Reference (IAPWS-IF97): 0.2 bar, 200 °C → v = 10.91 m³/kg; linear-in-p interpolation would give 21.8.
        let s = try solve("p=0.2bar, T=200C")
        #expect(close(s.v, 10.91, rel: 0.01))
    }

    @Test func readmeExampleIsTwoPhase() throws {
        let s = try solve("p=1bar, v=0.012m^3/kg")
        #expect(s.phase == .saturatedMixture)
        #expect(s.T == 99.63)
        #expect(close(s.x, (0.012 - 1.0432e-3) / (1.694 - 1.0432e-3)))
    }

    @Test func temperatureAndQuality() throws {
        let s = try solve("T=100C, x=0.5")
        #expect(s.p == 1.014)
        #expect(close(s.h, (419.04 + 2676.1) / 2))
        #expect(try solve("T=100C, x=0").phase == .saturatedLiquid)
        #expect(try solve("T=100C, x=1").phase == .saturatedVapor)
    }

    @Test func pressureAndEnthalpyInSuperheatedRegion() throws {
        let s = try solve("p=10bar, h=3008.2kJ/kg")
        #expect(close(s.T, 280, rel: 1e-6))
        #expect(close(s.s, 7.0465))
    }

    @Test func temperatureAndVolumeFindsPressure() throws {
        let s = try solve("T=280C, v=0.2480")
        #expect(close(s.p, 10, rel: 1e-6))
    }

    @Test func enthalpyAndEntropyFindsState() throws {
        let s = try solve("h=3008.2, s=7.0465")
        #expect(close(s.p, 10, rel: 1e-3))
        #expect(close(s.T, 280, rel: 1e-3))
    }

    @Test func compressedLiquidApproximation() throws {
        let s = try solve("p=50bar, T=100C")
        #expect(s.phase == .compressedLiquid)
        #expect(s.isApproximate)
        #expect(s.v == 1.0435e-3)
        #expect(close(s.h, 419.04 + 1.0435e-3 * (50 - 1.014) * 100))
        // Table A-5 gives 422.72 kJ/kg, so the approximation is within 0.5 %.
        #expect(close(s.h, 422.72, rel: 0.005))
    }

    @Test func supercriticalTablePoint() throws {
        let s = try solve("p=320bar, T=600C")
        #expect(s.phase == .supercriticalFluid)
        #expect(close(s.v, 0.01061))
        #expect(close(s.h, 3424.6))
    }

    @Test func qualityAndEnthalpyFindsPressure() throws {
        let sat = try #require(SteamTables.water.saturation(atPressure: 5))
        let h = sat.hf + 0.3 * (sat.hg - sat.hf)
        let s = try solve("x=0.3, h=\(h)")
        #expect(close(s.p, 5, rel: 1e-6))
    }

    @Test func idealGasBelowLowestIsobar() throws {
        let s = try solve("p=0.03bar, T=100C")
        #expect(s.isApproximate)
        #expect(s.phase == .superheatedVapor)
        // Reference (IAPWS-IF97): 0.03 bar, 100 °C → v = 57.5 m³/kg.
        #expect(close(s.v, 57.5, rel: 0.01))
    }

    @Test func errors() {
        #expect(throws: ThermoError.onSaturationLine) { try solve("p=10bar, T=179.9C") }
        #expect(throws: ThermoError.outOfRange) { try solve("p=1bar, T=1000C") }
        #expect(throws: ThermoError.invalidValue(.quality)) { try solve("p=1bar, x=1.5") }
        #expect(throws: ThermoError.sameProperty(.pressure)) {
            try solver.state(PropertyValue(.pressure, 1), PropertyValue(.pressure, 2))
        }
        #expect(throws: ThermoError.qualityAboveCriticalPoint) { try solve("p=250bar, x=0.5") }
        #expect(throws: ThermoError.compressedLiquidNeedsPressure(.specificVolume)) { try solve("T=50C, v=0.001") }
        #expect(throws: ThermoError.compressedLiquidNeedsPressure(.enthalpy)) { try solve("T=100C, h=400") }
    }

    /// Every pair of properties of a known state must solve back to that state.
    @Test(arguments: [
        (p: 0.5, T: 150.0), (p: 2.0, T: 400.0), (p: 10.0, T: 280.0), (p: 12.0, T: 300.0),
        (p: 45.0, T: 500.0), (p: 150.0, T: 600.0), (p: 280.0, T: 700.0), (p: 20.0, T: 100.0),
    ])
    func roundTrip(p: Double, T: Double) throws {
        let reference = try solver.state(p: p, T: T)
        let properties: [Property] = [.pressure, .temperature, .specificVolume, .internalEnergy, .enthalpy, .entropy]
        for (i, a) in properties.enumerated() {
            for b in properties[(i + 1)...] {
                let pa = PropertyValue(a, reference.value(of: a)!)
                let pb = PropertyValue(b, reference.value(of: b)!)
                // The liquid approximation makes v, u and s independent of p,
                // so only pairs with p determine a compressed liquid state.
                if reference.phase == .compressedLiquid, a != .pressure { continue }
                // h − u = pv is close to RT for steam, so u and h together barely constrain p.
                if (a, b) == (.internalEnergy, .enthalpy) { continue }
                let s = try solver.state(pa, pb)
                #expect(close(s.p, p, rel: 1e-3), "p from \(a.symbol), \(b.symbol)")
                #expect(close(s.T, T, rel: 1e-3), "T from \(a.symbol), \(b.symbol)")
            }
        }
    }

    @Test func twoPhaseRoundTrip() throws {
        let sat = try #require(SteamTables.water.saturation(atPressure: 5))
        let reference = solver.mixture(sat, x: 0.4)
        for (a, b) in [(Property.enthalpy, Property.entropy), (.specificVolume, .internalEnergy), (.pressure, .entropy), (.temperature, .enthalpy)] {
            let s = try solver.state(PropertyValue(a, reference.value(of: a)!), PropertyValue(b, reference.value(of: b)!))
            #expect(s.phase == .saturatedMixture)
            #expect(close(s.x, 0.4, rel: 1e-3), "x from \(a.symbol), \(b.symbol)")
            // With T given, the saturation pressure comes from Table A-2, which differs from A-3 in the last digit.
            #expect(close(s.p, 5, rel: a == .temperature ? 1e-2 : 1e-3), "p from \(a.symbol), \(b.symbol)")
        }
    }
}
