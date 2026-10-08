import Foundation

/// Parses queries such as `p=1bar, v=0.012m^3/kg` or `T = 200 C; x = 0.5`.
public enum InputParser {
    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case unknownProperty(String)
        case missingValue(String)
        case unknownUnit(String, Property)
        case wrongCount(Int)
        case duplicate(Property)

        public var description: String {
            switch self {
            case .unknownProperty(let name): "Unknown property “\(name)”. Use p, T, v, u, h, s or x."
            case .missingValue(let item): "No number found in “\(item)”."
            case .unknownUnit(let unit, let p): "“\(unit)” is not a unit for \(p.name.lowercased())."
            case .wrongCount(let n): "Enter exactly two properties (found \(n))."
            case .duplicate(let p): "\(p.name) was given twice."
            }
        }
    }

    /// Parses every `name = value unit` item in `text`.
    public static func parseItems(_ text: String) throws(ParseError) -> [PropertyValue] {
        let separators = CharacterSet(charactersIn: ",;\n")
        var result: [PropertyValue] = []
        for raw in text.components(separatedBy: separators) {
            let item = raw.trimmingCharacters(in: .whitespaces)
            if item.isEmpty { continue }
            result.append(try parseItem(item))
        }
        return result
    }

    /// Parses exactly two distinct properties, the input a state needs.
    public static func parse(_ text: String) throws(ParseError) -> (PropertyValue, PropertyValue) {
        let items = try parseItems(text)
        guard items.count == 2 else { throw .wrongCount(items.count) }
        guard items[0].property != items[1].property else { throw .duplicate(items[0].property) }
        return (items[0], items[1])
    }

    static func parseItem(_ item: String) throws(ParseError) -> PropertyValue {
        let parts = item.split(maxSplits: 1, whereSeparator: { $0 == "=" || $0 == ":" })
        guard parts.count == 2 else { throw .missingValue(item) }
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        guard let property = property(named: name) else { throw .unknownProperty(name) }

        let rest = parts[1].trimmingCharacters(in: .whitespaces)
        let (number, unit) = splitNumber(rest)
        guard let value = number else { throw .missingValue(item) }
        guard let base = Units.toBase(value, unit: unit, for: property) else {
            throw .unknownUnit(unit.trimmingCharacters(in: .whitespaces), property)
        }
        return PropertyValue(property, base)
    }

    static func property(named name: String) -> Property? {
        switch name.lowercased() {
        case "p", "pressure": .pressure
        case "t", "temp", "temperature": .temperature
        case "v", "volume", "specific volume": .specificVolume
        case "u", "internal energy": .internalEnergy
        case "h", "enthalpy": .enthalpy
        case "s", "entropy": .entropy
        case "x", "q", "quality": .quality
        default: nil
        }
    }

    /// Splits a leading decimal number (with optional exponent) from the unit that follows it.
    static func splitNumber(_ s: String) -> (Double?, String) {
        var end = s.startIndex
        var seenDigit = false
        var seenDot = false
        var seenExp = false
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c.isASCII, c.isNumber {
                seenDigit = true
                end = s.index(after: i)
            } else if c == ".", !seenDot, !seenExp {
                seenDot = true
            } else if (c == "-" || c == "+"), i == s.startIndex {
            } else if (c == "e" || c == "E"), seenDigit, !seenExp {
                // Only an exponent if a digit follows (optionally after a sign).
                var j = s.index(after: i)
                if j < s.endIndex, s[j] == "-" || s[j] == "+" { j = s.index(after: j) }
                guard j < s.endIndex, s[j].isASCII, s[j].isNumber else { break }
                seenExp = true
                i = j
                continue
            } else {
                break
            }
            i = s.index(after: i)
        }
        guard seenDigit else { return (nil, s) }
        return (Double(s[s.startIndex..<end]), String(s[end...]))
    }
}
