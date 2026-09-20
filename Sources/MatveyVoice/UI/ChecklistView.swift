import SwiftUI
import MatveyVoiceCore

struct ChecklistView: View {
    let model: AppModel
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .padding(.bottom, 8)
                Text(ui("checklist.title")).font(.system(size: 20, weight: .semibold))
                Text(ui("checklist.subtitle"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 48)
            .padding(.bottom, 24)

            Card {
                row(done: model.permissionsStatus.microphone == .granted, symbol: "mic",
                    title: ui("checklist.microphone"), detail: ui("checklist.microphone.detail")) {
                    Button(ui("checklist.openSettings")) { model.permissions.openSettings(.microphone) }
                    Button(ui("checklist.retry")) { Task { await model.permissions.request(.microphone) } }
                }
                CardDivider()
                row(done: model.permissionsStatus.accessibility == .granted && model.hotkeyAvailable,
                    symbol: "hand.raised",
                    title: ui("checklist.accessibility"), detail: ui("checklist.accessibility.detail")) {
                    Button(ui("checklist.openSettings")) { model.permissions.openSettings(.accessibility) }
                    Button(ui("checklist.retry")) {
                        Task { await model.permissions.request(.accessibility); model.restartHotkey() }
                    }
                }
                CardDivider()
                row(done: model.modelState == .ready, symbol: "arrow.down.circle",
                    title: ui("checklist.model"), detail: Self.modelText(model.modelState, modelID: model.settings.modelID)) {
                    if case .failed = model.modelState { Button(ui("checklist.retry")) { model.startPrepare() } }
                    if model.modelState == .notInstalled { Button(ui("checklist.retry")) { model.startPrepare() } }
                } extra: {
                    if case .downloading(let p) = model.modelState { ProgressView(value: p) }
                }
            }

            HStack {
                Spacer()
                Button(StatusLogic.isSetupComplete(permissions: model.permissionsStatus, model: model.modelState)
                       ? ui("checklist.done") : ui("checklist.later"), action: close)
                    .appButton(prominent: true)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 26)
        .frame(width: 500)
        .background(Color.windowFill)
        .tint(Brand.accent)
    }

    private func row<Buttons: View, Extra: View>(
        done: Bool, symbol: String, title: String, detail: String,
        @ViewBuilder buttons: () -> Buttons, @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) -> some View {
        CardRow {
            HStack(alignment: .top, spacing: 14) {
                indicator(done: done, symbol: symbol)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    extra().padding(.top, 4)
                    if !done {
                        HStack(spacing: 8) { buttons() }
                            .appButton()
                            .controlSize(.small)
                            .padding(.top, 6)
                            .transition(.opacity.combined(with: .offset(y: -4)))
                    }
                }
                .animation(Motion.appear, value: done)
            }
        }
    }

    /// Пока не сделано — контур со значком пункта; сделано — зелёный круг с галочкой.
    private func indicator(done: Bool, symbol: String) -> some View {
        ZStack {
            if done {
                Circle().fill(Color.green).transition(.scale(scale: 0.4).combined(with: .opacity))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else {
                Circle().strokeBorder(Color.primary.opacity(0.22), lineWidth: 1.25)
                Image(systemName: symbol).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
        .animation(Motion.appear, value: done)
        .accessibilityElement()
        .accessibilityLabel(ui(done ? "a11y.checklist.ready" : "a11y.checklist.pending"))
    }

    static func modelText(_ state: ModelState, modelID: String) -> String {
        let total = ModelCatalog.entry(for: modelID)?.approximateMegabytes ?? 0
        switch state {
        case .notInstalled: return ui("checklist.model.notInstalled", total)
        case .downloading(let p):
            return ui("checklist.model.downloading",
                      StatusLogic.downloadedMegabytes(progress: p, totalMegabytes: total), total)
        case .preparing: return ui("checklist.model.preparing")
        case .ready: return ui("checklist.model.ready")
        case .failed(let reason): return ui("checklist.model.failed", reason)
        }
    }
}
