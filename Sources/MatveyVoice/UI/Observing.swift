import Observation

/// Вызывает `read` сразу и после каждого изменения того, что она прочитала.
@MainActor
func trackChanges(_ read: @escaping @MainActor () -> Void) {
    withObservationTracking {
        read()
    } onChange: {
        Task { @MainActor in trackChanges(read) }
    }
}
