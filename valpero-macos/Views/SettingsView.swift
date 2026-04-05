import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    @State private var draftKey: String = ""
    @State private var showKey = false
    @State private var validating = false
    @State private var validationResult: ValidationResult? = nil
    @State private var saving = false
    @State private var saveError: String? = nil

    @State private var launchAtLogin: Bool = false

    private enum ValidationResult {
        case valid, invalid, networkError(String)

        var label: String {
            switch self {
            case .valid:              return "✓ Valid"
            case .invalid:            return "✗ Invalid key"
            case .networkError(let e): return "⚠ \(e)"
            }
        }
        var color: Color {
            switch self {
            case .valid:   return .green
            case .invalid: return .red
            case .networkError: return .orange
            }
        }
    }

    var body: some View {
        Form {
            // MARK: API Key section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if showKey {
                            TextField("val_key_…", text: $draftKey)
                                .font(.system(size: 12, design: .monospaced))
                                .onChange(of: draftKey) { _ in validationResult = nil }
                        } else {
                            SecureField("val_key_…", text: $draftKey)
                                .font(.system(size: 12, design: .monospaced))
                                .onChange(of: draftKey) { _ in validationResult = nil }
                        }
                        Button(showKey ? "Hide" : "Show") { showKey.toggle() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .cornerRadius(6)

                    HStack(spacing: 8) {
                        Button("Validate") {
                            validate()
                        }
                        .disabled(draftKey.trimmingCharacters(in: .whitespaces).isEmpty || validating)
                        .controlSize(.small)

                        if validating {
                            ProgressView().controlSize(.mini)
                        } else if let result = validationResult {
                            Text(result.label)
                                .font(.system(size: 11))
                                .foregroundStyle(result.color)
                        }

                        Spacer()

                        Button("Get API key →") {
                            NSWorkspace.shared.open(
                                URL(string: "https://valpero.com/dashboard/settings")!
                            )
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }

                    if let err = saveError {
                        Text(err).font(.system(size: 11)).foregroundStyle(.red)
                    }
                }
            } header: {
                Label("API Key", systemImage: "key")
            } footer: {
                Text("Your key is stored securely in the macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: Preferences section
            Section("Preferences") {
                Picker("Refresh every", selection: $state.refreshInterval) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                }

                Toggle("Show response time", isOn: $state.showResponseTime)
                Toggle("Show uptime %",      isOn: $state.showUptime)

                if #available(macOS 13.0, *) {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            state.launchAtLogin = newValue
                        }
                }
            }

            // MARK: Account section
            if state.hasKey {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected")
                            .font(.system(size: 12))
                        Spacer()
                        Button("Disconnect") {
                            draftKey = ""
                            validationResult = nil
                            state.clearKey()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    }
                } header: {
                    Label("Account", systemImage: "person.circle")
                }
            }

            // MARK: About
            Section {
                HStack {
                    Text("Version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appVersion)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("valpero.com") {
                        NSWorkspace.shared.open(URL(string: "https://valpero.com")!)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    Spacer()
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .onAppear {
            draftKey = state.apiKey
            if #available(macOS 13.0, *) {
                launchAtLogin = state.launchAtLogin
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(saving || draftKey == state.apiKey)
                    .keyboardShortcut(.return)
            }
        }
    }

    // MARK: - Validate

    private func validate() {
        let key = draftKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        validating = true
        validationResult = nil

        Task {
            do {
                let valid = try await APIClient.shared.validateKey(key)
                await MainActor.run {
                    validating = false
                    validationResult = valid ? .valid : .invalid
                }
            } catch let e as AppError {
                await MainActor.run {
                    validating = false
                    validationResult = .networkError(e.errorDescription ?? "Error")
                }
            } catch {
                await MainActor.run {
                    validating = false
                    validationResult = .networkError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        let key = draftKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        saving = true
        saveError = nil

        Task {
            do {
                try await state.saveKey(key)
                await MainActor.run {
                    saving = false
                    validationResult = .valid
                }
            } catch AppError.invalidKey {
                await MainActor.run {
                    saving = false
                    saveError = "Invalid API key — please check and try again."
                }
            } catch {
                await MainActor.run {
                    saving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
