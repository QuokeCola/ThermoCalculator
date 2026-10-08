import Testing
@testable import ThermoKit

@Suite("Input parser")
struct InputParserTests {
    @Test func readmeExample() throws {
        let (a, b) = try InputParser.parse("p=1bar, v=0.012m^3/kg")
        #expect(a == PropertyValue(.pressure, 1))
        #expect(b == PropertyValue(.specificVolume, 0.012))
    }

    @Test func unitsConvertToTableUnits() throws {
        let items = try InputParser.parseItems("P = 100 kPa; t=373.15 K; h=2.5e3 J/g; s = 7 kJ/(kg·K); x=50%; v=12 L/kg")
        #expect(items.map(\.property) == [.pressure, .temperature, .enthalpy, .entropy, .quality, .specificVolume])
        #expect(abs(items[0].value - 1) < 1e-12)
        #expect(abs(items[1].value - 100) < 1e-9)
        #expect(items[2].value == 2500)
        #expect(items[3].value == 7)
        #expect(items[4].value == 0.5)
        #expect(abs(items[5].value - 0.012) < 1e-12)
    }

    @Test func temperatureScales() throws {
        #expect(try InputParser.parseItems("T=212F")[0].value == 100)
        #expect(try InputParser.parseItems("T=100°C")[0].value == 100)
        #expect(try InputParser.parseItems("T=-5")[0].value == -5)
    }

    @Test func pressureUnits() throws {
        #expect(try InputParser.parseItems("p=1.5MPa")[0].value == 15)
        #expect(abs(try InputParser.parseItems("p=1atm")[0].value - 1.01325) < 1e-12)
    }

    @Test func errors() {
        #expect(throws: InputParser.ParseError.unknownProperty("w")) { try InputParser.parse("w=1, p=2") }
        #expect(throws: InputParser.ParseError.unknownUnit("furlong", .pressure)) { try InputParser.parse("p=1 furlong, T=2") }
        #expect(throws: InputParser.ParseError.missingValue("p=")) { try InputParser.parse("p=, T=2") }
        #expect(throws: InputParser.ParseError.wrongCount(1)) { try InputParser.parse("p=1") }
        #expect(throws: InputParser.ParseError.duplicate(.pressure)) { try InputParser.parse("p=1, P=2") }
    }
}
