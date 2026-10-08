import SwiftUI
import ThermoKit

struct ContentView: View {
    @Environment(HistoryStore.self) private var history
    @State private var query = ""
    @State private var selection: Calculation.ID?
    @State private var substance: Substance = .water
    @State private var showingSettings = false
    @State private var confirmingClear = false

    private let solver = ThermoSolver()

    /// The calculation for what is typed so far, shown live while typing.
    private var preview: Calculation? {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return Calculation(query: text, substance: substance, solver: solver)
    }

    private var selected: Calculation? {
        history.items.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if let preview {
                    Section("Result") {
                        CalculationRow(calculation: preview)
                            .contentShape(Rectangle())
                            .onTapGesture { submit() }
                    }
                }
                Section(history.items.isEmpty ? "" : "History") {
                    ForEach(history.items) { item in
                        NavigationLink(value: item.id) {
                            CalculationRow(calculation: item)
                        }
                        .contextMenu {
                            Button("Edit Query", systemImage: "pencil") { query = item.query }
                            Button("Delete", systemImage: "trash", role: .destructive) { history.remove(item) }
                        } preview: {
                            StateDetailView(calculation: item)
                                .frame(minWidth: 320, minHeight: 420)
                        }
                    }
                    .onDelete { history.remove(atOffsets: $0) }
                }
            }
            .overlay {
                if history.items.isEmpty && preview == nil {
                    ContentUnavailableView {
                        Label("Enter a State", systemImage: "thermometer.medium")
                    } description: {
                        Text("Type any two properties, for example\n**p = 1 bar, v = 0.012 m³/kg**")
                    }
                }
            }
            .navigationTitle(substance.name)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Enter any thermo state")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit(of: .search, submit)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Substance", selection: $substance) {
                            ForEach(Substance.allCases) { Text($0.name).tag($0) }
                        }
                    } label: {
                        Label("Substance", systemImage: "drop")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    Button("Clear History", systemImage: "trash") { confirmingClear = true }
                        .disabled(history.items.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    PropertyKeyBar(text: $query)
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    selection = nil
                    history.removeAll()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        } detail: {
            if let selected {
                StateDetailView(calculation: selected)
            } else {
                ContentUnavailableView("No State Selected", systemImage: "chart.xyaxis.line",
                                       description: Text("Pick a calculation from the history."))
            }
        }
    }

    private func submit() {
        guard let preview else { return }
        history.add(preview)
        selection = preview.id
        query = ""
    }
}

struct CalculationRow: View {
    let calculation: Calculation
    @AppStorage("pressureUnit") private var pressureUnit: PressureUnit = .bar
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(calculation.query)
                .font(.headline.monospaced())
            if let state = calculation.result {
                Text(state.phase.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(compact(state))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else if let message = calculation.errorMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    private func compact(_ state: ThermoState) -> String {
        Format.rows(for: state, pressure: pressureUnit, temperature: temperatureUnit)
            .filter { $0.property != .entropy && $0.property != .internalEnergy }
            .map { "\($0.property.symbol)=\($0.value)\($0.unit)" }
            .joined(separator: "  ")
    }
}

#Preview {
    ContentView()
        .environment(HistoryStore(fileURL: URL.temporaryDirectory.appending(path: "preview-history.json")))
}
