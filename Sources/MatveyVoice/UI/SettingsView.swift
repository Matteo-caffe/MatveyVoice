import SwiftUI
import MatveyVoiceCore

/// `@State` здесь недоступен (макрос SwiftUI не собирается на машине только с Command Line Tools),
/// поэтому черновик слова живёт в ObservableObject.
private final class WordDraft: ObservableObject {
    @Published var text = ""
}

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let model: AppModel
    @StateObject private var draft = WordDraft()

    var body: some View {
        Form {
            Section {
                Picker(ui("settings.hotkey"), selection: $settings.hotkey) {
                    ForEach(Hotkey.allCases, id: \.self) { Text(Self.name(of: $0)).tag($0) }
                }
                if settings.hotkey == .fn {
                    Text(ui("settings.hotkey.fnHint")).font(.footnote).foregroundStyle(.secondary)
                }
                Picker(ui("settings.mode"), selection: $settings.triggerMode) {
                    Text(ui("settings.mode.hold")).tag(TriggerMode.hold)
                    Text(ui("settings.mode.toggle")).tag(TriggerMode.toggle)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Picker(ui("settings.language"), selection: $settings.language) {
                    Text(ui("settings.language.auto")).tag(Language.auto)
                    Text(ui("settings.language.ru")).tag(Language.ru)
                    Text(ui("settings.language.en")).tag(Language.en)
                }
                Text(ui("settings.language.note")).font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Picker(ui("settings.model"), selection: $settings.modelID) {
                    ForEach(ModelCatalog.entries, id: \.modelID) { entry in
                        Text(ui("settings.model.\(entry.modelID)", entry.approximateMegabytes)).tag(entry.modelID)
                    }
                }
                modelStatus
            }
            Section(ui("settings.dictionary")) {
                Text(ui("settings.dictionary.note")).font(.footnote).foregroundStyle(.secondary)
                ForEach(Array(settings.dictionary.enumerated()), id: \.offset) { index, word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button(role: .destructive) {
                            settings.dictionary.remove(at: index)
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(ui("settings.dictionary.remove"))
                    }
                }
                HStack {
                    TextField(ui("settings.dictionary.placeholder"), text: $draft.text)
                        .onSubmit(addWord)
                    Button(ui("settings.dictionary.add"), action: addWord)
                        .disabled(draft.text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section {
                Toggle(ui("settings.removeFillers"), isOn: $settings.removeFillers)
                Toggle(ui("settings.launchAtLogin"), isOn: $settings.launchAtLogin)
                if let error = model.launchAtLoginError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 620)
    }

    @ViewBuilder private var modelStatus: some View {
        switch model.switchProgress {
        case .downloading(let p):
            ProgressView(value: p) { Text(ui("settings.model.switching", Int((p * 100).rounded()))) }
        case .preparing:
            Text(ui("settings.model.preparing")).font(.footnote).foregroundStyle(.secondary)
        case .failed(let reason):
            HStack {
                Text(ui("settings.model.switchFailed", reason)).font(.footnote).foregroundStyle(.red)
                Button(ui("checklist.retry")) { model.startPrepare() }
            }
        default:
            Text(ChecklistView.modelText(model.modelState, modelID: settings.modelID))
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func addWord() {
        let word = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        if !settings.dictionary.contains(word) { settings.dictionary.append(word) }
        draft.text = ""
    }

    static func name(of hotkey: Hotkey) -> String {
        switch hotkey {
        case .rightOption: ui("hotkey.rightOption")
        case .rightCommand: ui("hotkey.rightCommand")
        case .rightControl: ui("hotkey.rightControl")
        case .fn: ui("hotkey.fn")
        }
    }
}
