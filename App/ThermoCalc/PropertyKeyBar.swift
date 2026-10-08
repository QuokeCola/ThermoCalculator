import SwiftUI

/// Keys above the keyboard for property names and units, the successor of the original app's state keyboard.
struct PropertyKeyBar: View {
    @Binding var text: String

    private static let properties = ["p", "T", "v", "u", "h", "s", "x"]

    /// Units offered after the most recently typed property.
    private var units: [String] {
        switch lastProperty {
        case "p": ["bar", "kPa", "MPa"]
        case "T": ["°C", "K"]
        case "v": ["m³/kg"]
        case "u", "h": ["kJ/kg"]
        case "s": ["kJ/kg·K"]
        default: []
        }
    }

    private var lastProperty: String? {
        let current = text.split(separator: ",").last.map(String.init) ?? ""
        guard let name = current.split(separator: "=").first?.trimmingCharacters(in: .whitespaces),
              current.contains("=") else { return nil }
        return Self.properties.first { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    private var expectingProperty: Bool {
        let current = text.split(separator: ",", omittingEmptySubsequences: false).last ?? ""
        return !current.contains("=")
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if expectingProperty {
                    ForEach(Self.properties, id: \.self) { name in
                        key(name) { insert("\(name) = ") }
                    }
                } else {
                    ForEach(units, id: \.self) { unit in
                        key(unit) { insert(unit) }
                    }
                    key(",") { insert(", ") }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .font(.body.monospaced())
    }

    private func insert(_ s: String) {
        text += s
    }
}
