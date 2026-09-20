import SwiftUI
import MatveyVoiceCore

/// `@State` здесь недоступен (макрос SwiftUI не собирается на машине только с Command Line Tools),
/// поэтому изменяемое состояние экрана живёт в ObservableObject.
private final class WordDraft: ObservableObject {
    @Published var text = ""
}

private enum SettingsTab: CaseIterable {
    case general, recognition, dictionary

    var titleKey: String {
        switch self {
        case .general: "settings.tab.general"
        case .recognition: "settings.tab.recognition"
        case .dictionary: "settings.dictionary"
        }
    }

    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .recognition: "waveform"
        case .dictionary: "text.book.closed"
        }
    }
}

private final class SettingsNav: ObservableObject {
    @Published var tab: SettingsTab = .general
}

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let model: AppModel
    @StateObject private var draft = WordDraft()
    @StateObject private var nav = SettingsNav()
    @Namespace private var tabSelection

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            if !Self.usesGlass { Rectangle().fill(Color.hairline).frame(width: 0.5).ignoresSafeArea() }
            content
        }
        .frame(width: 680, height: 520)
        .background { windowBackground }
        .tint(Brand.accent)
    }

    private static var usesGlass: Bool {
        if #available(macOS 26, *) { true } else { false }
    }

    /// На macOS 26+ окно чуть просвечивает рабочим столом, чтобы стеклу было что преломлять.
    @ViewBuilder private var windowBackground: some View {
        if #available(macOS 26, *) {
            VisualEffectBackground(material: .underWindowBackground).ignoresSafeArea()
        } else {
            Color.windowFill.ignoresSafeArea()
        }
    }

    // MARK: боковая панель

    @ViewBuilder private var sidebar: some View {
        if #available(macOS 26, *) {
            // Плавающая стеклянная панель: значки окна лежат на ней, вокруг остаётся поле.
            sidebarContent
                .padding(.horizontal, 12)
                .padding(.top, 20)
                .padding(.bottom, 14)
                .frame(width: 200)
                .frame(maxHeight: .infinity, alignment: .top)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(10)
        } else {
            sidebarContent
                .padding(.horizontal, 12)
                .padding(.top, 46)
                .padding(.bottom, 14)
                .frame(width: 200)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(VisualEffectBackground(material: .sidebar).ignoresSafeArea())
        }
    }

    private var sidebarContent: some View {
        let status = model.menuStatus
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 34, height: 34)
                Text("MatveyVoice").font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 18)
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                StatusDot(color: Color(nsColor: status.indicatorColor), size: 7)
                Text(StatusMenuController.title(for: status))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
            .animation(Motion.select, value: status)
        }
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let selected = nav.tab == tab
        return Button { withAnimation(Motion.select) { nav.tab = tab } } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(selected ? Brand.accent : Color.secondary)
                Text(ui(tab.titleKey)).font(.system(size: 13, weight: selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.09))
                        .matchedGeometryEffect(id: "tabSelection", in: tabSelection)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: содержимое

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(ui(nav.tab.titleKey)).font(.system(size: 22, weight: .semibold))
                pane
            }
            .id(nav.tab)
            .transition(.opacity.combined(with: .offset(y: 8)))
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var pane: some View {
        switch nav.tab {
        case .general: generalPane
        case .recognition: recognitionPane
        case .dictionary: dictionaryPane
        }
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            Block(title: ui("settings.hotkey"),
                  footer: settings.hotkey == .fn ? ui("settings.hotkey.fnHint") : nil) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(Hotkey.allCases, id: \.self) { hotkey in
                            Button { settings.hotkey = hotkey } label: {
                                Keycap(spec: hotkey.keySpec, selected: settings.hotkey == hotkey)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Self.name(of: hotkey))
                            .accessibilityAddTraits(settings.hotkey == hotkey ? .isSelected : [])
                        }
                    }
                    Text(Self.name(of: settings.hotkey))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            Block(title: ui("settings.mode")) {
                VStack(alignment: .leading, spacing: 10) {
                    SegmentedChoice(
                        options: [(TriggerMode.hold, ui("settings.mode.hold")), (.toggle, ui("settings.mode.toggle"))],
                        selection: $settings.triggerMode)
                    Text(ui(settings.triggerMode == .hold ? "settings.mode.hold.detail" : "settings.mode.toggle.detail"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            Block {
                toggleRow(title: ui("settings.launchAtLogin"), isOn: $settings.launchAtLogin)
                if let error = model.launchAtLoginError {
                    CardDivider()
                    CardRow { Text(error).font(.system(size: 12)).foregroundStyle(.red) }
                }
            }
        }
    }

    private var recognitionPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            Block(title: ui("settings.language"), footer: ui("settings.language.note")) {
                SegmentedChoice(
                    options: [(Language.auto, ui("settings.language.auto")), (.ru, ui("settings.language.ru")),
                              (.en, ui("settings.language.en"))],
                    selection: $settings.language)
                    .padding(14)
            }
            Block(title: ui("settings.model")) {
                ForEach(Array(ModelCatalog.entries.enumerated()), id: \.element.modelID) { index, entry in
                    if index > 0 { CardDivider() }
                    modelOption(entry)
                }
                CardDivider()
                CardRow { modelStatus }
            }
            Block {
                toggleRow(title: ui("settings.removeFillers"), isOn: $settings.removeFillers)
            }
        }
    }

    private var dictionaryPane: some View {
        Block(footer: ui("settings.dictionary.note")) {
            if !settings.dictionary.isEmpty {
                CardRow {
                    FlowLayout(spacing: 6) {
                        ForEach(settings.dictionary, id: \.self) { word in
                            wordChip(word).transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                }
                CardDivider()
            }
            CardRow {
                HStack(spacing: 8) {
                    WordField(text: $draft.text, placeholder: ui("settings.dictionary.placeholder"), onSubmit: addWord)
                    Button(ui("settings.dictionary.add"), action: addWord)
                        .appButton()
                        .disabled(draft.text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .animation(Motion.appear, value: settings.dictionary)
    }

    // MARK: элементы

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        CardRow {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer(minLength: 12)
                Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch)
            }
        }
    }

    private func modelOption(_ entry: ModelCatalog.Entry) -> some View {
        let selected = settings.modelID == entry.modelID
        return Button { withAnimation(Motion.select) { settings.modelID = entry.modelID } } label: {
            HStack(spacing: 12) {
                RadioMark(selected: selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ui("settings.model.name.\(entry.modelID)")).font(.system(size: 13, weight: .medium))
                    Text(ui("settings.model.detail.\(entry.modelID)"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(ui("settings.model.size", entry.approximateMegabytes))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func wordChip(_ word: String) -> some View {
        HStack(spacing: 5) {
            Text(word).font(.system(size: 13))
            Button {
                withAnimation(Motion.appear) { settings.dictionary.removeAll { $0 == word } }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ui("settings.dictionary.remove"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder private var modelStatus: some View {
        switch model.switchProgress {
        case .downloading(let p):
            VStack(alignment: .leading, spacing: 8) {
                statusLine(.blue, ui("settings.model.switching", Int((p * 100).rounded())))
                ProgressView(value: p)
            }
        case .preparing:
            statusLine(.blue, ui("settings.model.preparing"))
        case .failed(let reason):
            HStack(spacing: 10) {
                statusLine(.red, ui("settings.model.switchFailed", reason))
                Spacer(minLength: 0)
                Button(ui("checklist.retry")) { model.startPrepare() }.appButton()
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                statusLine(Self.color(of: model.modelState),
                           ChecklistView.modelText(model.modelState, modelID: settings.modelID))
                if case .downloading(let p) = model.modelState { ProgressView(value: p) }
            }
        }
    }

    private func statusLine(_ color: Color, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            StatusDot(color: color, size: 7)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private static func color(of state: ModelState) -> Color {
        switch state {
        case .ready: .green
        case .failed: .red
        case .notInstalled: .orange
        case .downloading, .preparing: .blue
        }
    }

    private func addWord() {
        let word = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        withAnimation(Motion.appear) {
            if !settings.dictionary.contains(word) { settings.dictionary.append(word) }
        }
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

// MARK: клавиша и переключатель

private struct KeySpec {
    enum Glyph { case text(String), symbol(String) }
    let glyph: Glyph
    /// Надпись на клавише: на клавиатурах Mac она английская в любой локали.
    let word: String
}

private extension Hotkey {
    var keySpec: KeySpec {
        switch self {
        case .rightOption: KeySpec(glyph: .text("⌥"), word: "option")
        case .rightCommand: KeySpec(glyph: .text("⌘"), word: "command")
        case .rightControl: KeySpec(glyph: .text("⌃"), word: "control")
        case .fn: KeySpec(glyph: .symbol("globe"), word: "fn")
        }
    }
}

/// Клавиша с «бортиком»; выбранная как будто нажата.
private struct Keycap: View {
    let spec: KeySpec
    let selected: Bool
    private let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        ZStack(alignment: .top) {
            shape
                .fill(selected ? Brand.accent.opacity(0.55) : Color.keyLip)
                .frame(height: 62)
                .offset(y: 3)
            face.offset(y: selected ? 2 : 0)
        }
        .frame(height: 65)
        .animation(.snappy(duration: 0.28), value: selected)
    }

    private var face: some View {
        VStack(alignment: .leading, spacing: 0) {
            glyph
                .font(.system(size: 17, weight: .medium))
            Spacer(minLength: 0)
            Text(spec.word).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(selected ? Brand.accent : Color.primary.opacity(0.85))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 62)
        .background(Color.keyFace, in: shape)
        .overlay(shape.fill(selected ? Brand.accent.opacity(0.10) : .clear))
        .overlay(shape.strokeBorder(selected ? Brand.accent : Color.primary.opacity(0.16), lineWidth: selected ? 1.25 : 0.75))
    }

    @ViewBuilder private var glyph: some View {
        switch spec.glyph {
        case .text(let text): Text(text)
        case .symbol(let name): Image(systemName: name)
        }
    }
}

private struct RadioMark: View {
    let selected: Bool

    var body: some View {
        ZStack {
            Circle().strokeBorder(selected ? Brand.accent : Color.primary.opacity(0.3), lineWidth: 1.25)
            if selected { Circle().fill(Brand.accent).padding(3.5) }
        }
        .frame(width: 16, height: 16)
        .animation(Motion.select, value: selected)
        .accessibilityHidden(true)
    }
}

/// Сегментированный выбор в стиле приложения. На macOS 26+ ползунок — жидкое стекло, которое перетекает
/// между сегментами; раньше — плоский ползунок с тенью.
private struct SegmentedChoice<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var thumb

    var body: some View {
        segments
            .padding(2)
            .background(Color.primary.opacity(0.07), in: Capsule())
    }

    @ViewBuilder private var segments: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 4) { row }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let (value, title) = options[index]
                let selected = value == selection
                Button {
                    withAnimation(Motion.select) { selection = value }
                } label: {
                    segment(title, selected: selected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    /// Стекло накладывается на сам сегмент вместе с подписью: иначе оно легло бы поверх текста.
    @ViewBuilder private func segment(_ title: String, selected: Bool) -> some View {
        let label = Text(title)
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .contentShape(Capsule())
        if selected {
            if #available(macOS 26, *) {
                label
                    .glassEffect(.regular, in: Capsule())
                    .glassEffectID("thumb", in: thumb)
            } else {
                label.background {
                    Capsule()
                        .fill(Color.segmentThumb)
                        .shadow(color: .black.opacity(0.14), radius: 1.5, y: 0.5)
                        .matchedGeometryEffect(id: "thumb", in: thumb)
                }
            }
        } else {
            label
        }
    }
}

/// Поле ввода слова: рамка меняет цвет на акцентный вместо синего системного кольца фокуса.
private struct WordField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .focused($focused)
            .focusEffectDisabled()
            .onSubmit(onSubmit)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.primary.opacity(0.06), in: shape)
            .overlay(shape.strokeBorder(focused ? Brand.accent : Color.hairline, lineWidth: focused ? 1.25 : 0.75))
    }
}
