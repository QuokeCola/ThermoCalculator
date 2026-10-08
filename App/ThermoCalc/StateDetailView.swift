import SwiftUI
import ThermoKit

struct StateDetailView: View {
    let calculation: Calculation
    @AppStorage("pressureUnit") private var pressureUnit: PressureUnit = .bar
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    var body: some View {
        Form {
            Section("Input") {
                Text(calculation.query)
                    .font(.body.monospaced())
                LabeledContent("Substance", value: calculation.substance.name)
            }

            if let state = calculation.result {
                Section {
                    LabeledContent("Phase", value: state.phase.name)
                } footer: {
                    if state.isApproximate {
                        Text(approximationNote(state))
                    }
                }

                Section("Properties") {
                    ForEach(Format.rows(for: state, pressure: pressureUnit, temperature: temperatureUnit)) { row in
                        LabeledContent {
                            Text(row.valueWithUnit)
                                .monospacedDigit()
                                .textSelection(.enabled)
                        } label: {
                            Text("\(row.property.name) (\(row.property.symbol))")
                        }
                    }
                }
            } else if let message = calculation.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("State")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let state = calculation.result {
                ShareLink(item: calculation.query + "\n" + Format.summary(for: state, pressure: pressureUnit, temperature: temperatureUnit))
            }
        }
    }

    private func approximationNote(_ state: ThermoState) -> String {
        switch state.phase {
        case .compressedLiquid:
            "Approximated from saturated liquid at the same temperature (v, u, s ≈ f-values, h ≈ hf + vf·(p − psat))."
        default:
            "Below the lowest tabulated superheated pressure, so the vapor is treated as an ideal gas."
        }
    }
}
