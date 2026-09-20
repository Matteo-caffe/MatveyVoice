import SwiftUI
import MatveyVoiceCore

struct ChecklistView: View {
    let model: AppModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(ui("checklist.title")).font(.title2.bold())
            Text(ui("checklist.subtitle")).foregroundStyle(.secondary)

            row(done: model.permissionsStatus.microphone == .granted,
                title: ui("checklist.microphone"), detail: ui("checklist.microphone.detail")) {
                Button(ui("checklist.openSettings")) { model.permissions.openSettings(.microphone) }
                Button(ui("checklist.retry")) { Task { await model.permissions.request(.microphone) } }
            }
            row(done: model.permissionsStatus.accessibility == .granted && model.hotkeyAvailable,
                title: ui("checklist.accessibility"), detail: ui("checklist.accessibility.detail")) {
                Button(ui("checklist.openSettings")) { model.permissions.openSettings(.accessibility) }
                Button(ui("checklist.retry")) {
                    Task { await model.permissions.request(.accessibility); model.restartHotkey() }
                }
            }
            row(done: model.modelState == .ready,
                title: ui("checklist.model"), detail: Self.modelText(model.modelState, modelID: model.settings.modelID)) {
                if case .failed = model.modelState { Button(ui("checklist.retry")) { model.startPrepare() } }
                if model.modelState == .notInstalled { Button(ui("checklist.retry")) { model.startPrepare() } }
            } extra: {
                if case .downloading(let p) = model.modelState { ProgressView(value: p) }
            }

            HStack {
                Spacer()
                Button(StatusLogic.isSetupComplete(permissions: model.permissionsStatus, model: model.modelState)
                       ? ui("checklist.done") : ui("checklist.later"), action: close)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func row<Buttons: View, Extra: View>(
        done: Bool, title: String, detail: String,
        @ViewBuilder buttons: () -> Buttons, @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title2)
                .foregroundStyle(done ? Color.green : Color.orange)
                .accessibilityLabel(ui(done ? "a11y.checklist.ready" : "a11y.checklist.pending"))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                extra()
                if !done { HStack { buttons() } }
            }
        }
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
