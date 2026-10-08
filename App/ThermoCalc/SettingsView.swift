import SwiftUI
import ThermoKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pressureUnit") private var pressureUnit: PressureUnit = .bar
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    var body: some View {
        NavigationStack {
            Form {
                Section("Display Units") {
                    Picker("Pressure", selection: $pressureUnit) {
                        ForEach(PressureUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Temperature", selection: $temperatureUnit) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section {
                    Text("Input accepts p in Pa, kPa, MPa, bar, atm or psi; T in °C, K or °F; v in m³/kg or L/kg; u and h in kJ/kg or J/kg; s in kJ/(kg·K). Values without a unit use bar, °C, m³/kg, kJ/kg and kJ/(kg·K).")
                } header: {
                    Text("Input")
                }
                Section {
                    Text("Linear interpolation in the SI steam tables A-2, A-3 and A-4 of Moran & Shapiro, Fundamentals of Engineering Thermodynamics.")
                } header: {
                    Text("Data")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
