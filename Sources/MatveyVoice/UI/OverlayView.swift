import SwiftUI
import Observation

@MainActor
@Observable
final class OverlayModel {
    enum Content: Equatable { case recording, transcribing, text(String) }
    var content: Content = .transcribing
    var level: Float = 0
    /// Появление и исчезновение плашки анимируются; окно скрывается уже после анимации.
    var isShown = false
    @ObservationIgnored var recordingStart = Date()
    @ObservationIgnored let wave = WaveSmoother()
}

/// Плавный уровень для анимации: события уровня приходят ~12 раз в секунду, кадров нужно 60+.
/// Быстро нарастает на звук и медленно спадает.
@MainActor
final class WaveSmoother {
    private var value = 0.0
    private var lastTime = 0.0

    func reset() {
        value = 0
        lastTime = 0
    }

    func step(toward rawLevel: Double, at time: Double) -> Double {
        // Шум комнаты (~-45 дБ) не должен шевелить волну: срезаем низ. Вход уже в дБ (AudioRecorder),
        // поэтому дальше без искусственного сжатия — иначе тихая и громкая речь выглядят одинаково.
        let target = max(0, (rawLevel - 0.12) / 0.88)
        let dt = min(max(time - lastTime, 0), 0.1)
        lastTime = time
        let rate = target > value ? 16.0 : 5.0
        value += (target - value) * (1 - exp(-rate * dt))
        return value
    }
}

enum OverlayMetrics {
    /// Окно больше самой плашки: в запасе место под тень и рост текста вверх.
    static let panelSize = CGSize(width: 440, height: 170)
}

struct OverlayView: View {
    let model: OverlayModel

    var body: some View {
        pill
            .scaleEffect(model.isShown ? 1 : 0.86, anchor: .bottom)
            .opacity(model.isShown ? 1 : 0)
            .offset(y: model.isShown ? 0 : 12)
            .padding(.bottom, 30)
            .frame(width: OverlayMetrics.panelSize.width, height: OverlayMetrics.panelSize.height, alignment: .bottom)
            .animation(.spring(response: 0.46, dampingFraction: 0.8), value: model.isShown)
    }

    @ViewBuilder private var pill: some View {
        if #available(macOS 26, *) {
            GlassPill(model: model)
        } else {
            ClassicPill(model: model)
        }
    }
}

// MARK: содержимое состояний (общее для обоих видов; цвет «чернил» задаёт вид плашки)

/// Волна и таймер записи.
private struct WaveTimer: View {
    let model: OverlayModel
    let ink: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let t = reduceMotion ? 0 : now
            let level = model.wave.step(toward: Double(model.level), at: now)
            HStack(spacing: 12) {
                WaveBars(level: level, t: t, ink: ink)
                    .accessibilityLabel(ui("a11y.overlay.level"))
                Text(Self.elapsed(from: model.recordingStart, to: context.date))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(ink.opacity(0.55))
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ui("overlay.recording"))
    }

    static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Лампочка записи: ровная точка, от которой раз в полторы секунды расходится тонкое кольцо.
private struct RecordDot: View {
    var size: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let ripple = t.truncatingRemainder(dividingBy: 1.6) / 1.6
            ZStack {
                Circle()
                    .strokeBorder(Brand.accent.opacity(0.6 * (1 - ripple)), lineWidth: 1)
                    .scaleEffect(1 + ripple * 1.1)
                Circle().fill(Brand.accent)
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

/// Столбики волны вокруг средней линии: высота — голос, умноженный на две бегущие синусоиды, по краям спад.
private struct WaveBars: View {
    let level: Double
    let t: Double
    let ink: Color
    static let count = 28

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<Self.count, id: \.self) { index in
                let x = Double(index) / Double(Self.count - 1)
                let envelope = 0.3 + 0.7 * sin(x * .pi)
                let motion = 0.55 * (0.5 + 0.5 * sin(t * 7.0 + Double(index) * 0.55))
                    + 0.45 * (0.5 + 0.5 * sin(t * 4.3 - Double(index) * 0.9))
                // В тишине волна чуть дышит, чтобы было видно, что запись идёт.
                let idle = 0.08 + 0.05 * motion
                // Бегущая волна — лёгкая рябь поверх голоса, а не отдельный источник амплитуды: раньше она
                // качала высоту от 0.3× до 1.0×, из-за чего громкость почти не читалась за анимацией.
                let voice = level * (0.72 + 0.28 * motion)
                let amplitude = max(idle, voice)
                Capsule()
                    .fill(ink.opacity(0.45 + 0.5 * min(1, amplitude * envelope * 1.6)))
                    .frame(width: 2.5, height: 4 + 26 * amplitude * envelope)
            }
        }
        .frame(height: 32)
    }
}

/// Три точки и подпись «Распознаю…».
private struct TranscribingContent: View {
    let ink: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        let pulse = 0.5 + 0.5 * sin(t * 5 - Double(index) * 0.9)
                        Circle()
                            .fill(ink)
                            .frame(width: 5, height: 5)
                            .opacity(reduceMotion ? 0.7 : 0.25 + 0.75 * pulse)
                    }
                }
                .accessibilityHidden(true)
                Text(ui("overlay.transcribing"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ink.opacity(0.8))
            }
        }
    }
}

private struct MessageContent: View {
    let text: String
    let ink: Color

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ink.opacity(0.92))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 340)
    }
}

// MARK: Liquid Glass (macOS 26+)

/// Два стеклянных элемента в одном контейнере: «бусина» записи и капсула с содержимым.
/// При смене состояния бусина втягивается в капсулу, а капсула плавно меняет размер, как капля.
@available(macOS 26, *)
private struct GlassPill: View {
    let model: OverlayModel
    @Namespace private var glass

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 8) {
                if case .recording = model.content {
                    RecordDot(size: 12)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.tint(Brand.accent.opacity(0.32)), in: Circle())
                        .glassEffectID("orb", in: glass)
                }
                content
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(width: bodyWidth)
                    .frame(minHeight: 44)
                    .glassEffect(.regular, in: shape)
                    .glassEffectID("body", in: glass)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: model.content)
    }

    @ViewBuilder private var content: some View {
        ZStack {
            switch model.content {
            case .recording:
                WaveTimer(model: model, ink: .primary).transition(.opacity.combined(with: .scale(scale: 0.92)))
            case .transcribing:
                TranscribingContent(ink: .primary).transition(.opacity.combined(with: .scale(scale: 0.92)))
            case .text(let text):
                MessageContent(text: text, ink: .primary).transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    private var bodyWidth: CGFloat? {
        if case .recording = model.content { return 218 }
        return nil
    }
}

// MARK: запасной вид (macOS 14–25)

/// Плашка всегда тёмная, как HUD: читается на любом фоне и не зависит от темы системы.
private struct ClassicPill: View {
    let model: OverlayModel

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        ZStack {
            switch model.content {
            case .recording:
                HStack(spacing: 12) {
                    RecordDot()
                    WaveTimer(model: model, ink: .white)
                }
                .transition(.opacity)
            case .transcribing:
                TranscribingContent(ink: .white).transition(.opacity)
            case .text(let text):
                MessageContent(text: text, ink: .white).transition(.opacity)
            }
        }
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(width: fixedWidth)
        .frame(minHeight: 44)
        .background(Color(white: 0.10).opacity(0.96), in: shape)
        .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .shadow(color: .black.opacity(0.22), radius: 1.5)
        .animation(.spring(response: 0.42, dampingFraction: 0.85), value: model.content)
    }

    private var fixedWidth: CGFloat? {
        if case .recording = model.content { return 232 }
        return nil
    }
}
