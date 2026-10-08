import Foundation
import ThermoKit

/// Substances the app can calculate. Only water has tables so far.
enum Substance: String, CaseIterable, Codable, Identifiable {
    case water

    var id: String { rawValue }
    var name: String { "Water" }
}

/// One query and its outcome, as kept in the history.
struct Calculation: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var substance: Substance = .water
    var query: String
    var result: ThermoState?
    var errorMessage: String?

    init(query: String, substance: Substance = .water, solver: ThermoSolver = ThermoSolver()) {
        self.query = query
        self.substance = substance
        do {
            result = try solver.state(for: query)
        } catch let error as CustomStringConvertible {
            errorMessage = error.description
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

