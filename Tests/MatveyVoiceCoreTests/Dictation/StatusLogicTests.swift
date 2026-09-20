import Testing
@testable import MatveyVoiceCore

@Suite struct StatusLogicTests {
    private let ok = PermissionsStatus(microphone: .granted, accessibility: .granted)

    private func status(_ d: DictationState = .idle, _ p: PermissionsStatus? = nil,
                        hotkey: Bool = true, model: ModelState = .ready) -> MenuStatus {
        StatusLogic.menuStatus(dictation: d, permissions: p ?? ok, hotkeyAvailable: hotkey, model: model)
    }

    @Test func readyWhenEverythingIsFine() {
        #expect(status() == .ready)
        #expect(!status().isProblem)
    }

    @Test func revokedMicrophoneIsAProblem() {
        #expect(status(.idle, PermissionsStatus(microphone: .denied, accessibility: .granted)) == .noMicrophone)
        #expect(status(.idle, PermissionsStatus(microphone: .notDetermined, accessibility: .granted)) == .noMicrophone)
    }

    @Test func revokedAccessibilityOrDeadTapNeedsAccess() {
        #expect(status(.idle, PermissionsStatus(microphone: .granted, accessibility: .notDetermined)) == .needAccessibility)
        #expect(status(hotkey: false) == .needAccessibility)
    }

    @Test func priorityMicrophoneThenAccessThenModelThenMessage() {
        let none = PermissionsStatus(microphone: .denied, accessibility: .notDetermined)
        #expect(status(.idle, none, hotkey: false, model: .notInstalled) == .noMicrophone)
        #expect(status(.idle, PermissionsStatus(microphone: .granted, accessibility: .notDetermined), model: .notInstalled) == .needAccessibility)
        #expect(status(model: .notInstalled) == .modelMissing)
        #expect(status(model: .preparing) == .modelPreparing)
        #expect(status(model: .failed(reason: "x")) == .modelFailed("x"))
        #expect(status(.message(text: "hi"), model: .preparing) == .modelPreparing)
        #expect(status(.message(text: "hi")) == .message("hi"))
    }

    @Test func activeDictationWinsOverEverything() {
        let none = PermissionsStatus(microphone: .denied, accessibility: .denied)
        #expect(status(.recording, none, hotkey: false, model: .notInstalled) == .recording)
        #expect(status(.transcribing, none) == .processing)
        #expect(status(.inserting) == .processing)
    }

    @Test func downloadCarriesProgress() {
        #expect(status(model: .downloading(progress: 0.4)) == .modelDownloading(0.4))
    }

    @Test func megabyteProgressIsClampedAndRounded() {
        #expect(StatusLogic.downloadedMegabytes(progress: -1, totalMegabytes: 250) == 0)
        #expect(StatusLogic.downloadedMegabytes(progress: 0.5, totalMegabytes: 250) == 125)
        #expect(StatusLogic.downloadedMegabytes(progress: 2, totalMegabytes: 250) == 250)
    }

    @Test func checklistNeededUntilSetupDoneOrWhenPermissionRevoked() {
        #expect(StatusLogic.needsChecklist(setupCompleted: false, permissions: ok))
        #expect(!StatusLogic.needsChecklist(setupCompleted: true, permissions: ok))
        #expect(StatusLogic.needsChecklist(setupCompleted: true,
                                           permissions: PermissionsStatus(microphone: .denied, accessibility: .granted)))
        #expect(StatusLogic.needsChecklist(setupCompleted: true,
                                           permissions: PermissionsStatus(microphone: .granted, accessibility: .notDetermined)))
    }

    @Test func setupCompleteNeedsPermissionsAndReadyModel() {
        #expect(StatusLogic.isSetupComplete(permissions: ok, model: .ready))
        #expect(!StatusLogic.isSetupComplete(permissions: ok, model: .preparing))
        #expect(!StatusLogic.isSetupComplete(permissions: PermissionsStatus(microphone: .denied, accessibility: .granted), model: .ready))
    }
}
