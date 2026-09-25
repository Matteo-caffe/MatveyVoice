import AppKit
import SwiftUI
import MatveyVoiceCore

/// Визуальный язык приложения: системные нейтральные цвета и один акцент.
/// Акцент — «сигнальный» оранжево-красный, как лампочка записи; им подсвечено только активное.
enum Brand {
    static let accent = Color(red: 0.90, green: 0.27, blue: 0.06)
    /// Золотистый край того же акцента (тёплая часть спектра, без новых оттенков) — второй стоп подложки
    /// переключения; разница с `accent` нарочно заметна, иначе на маленькой клавише градиент не читается.
    static let accentWarm = Color(red: 1.00, green: 0.74, blue: 0.16)
    /// Подложка, которая скользит между вариантами при переключении (сегменты, вкладки, клавиша, модель):
    /// двухцветный градиент в одной цветовой семье, а не плоская заливка.
    static let switchFill = LinearGradient(colors: [accent, accentWarm], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension MenuStatus {
    /// Цвет индикатора состояния: зелёный — готово, красный — запись, синий — работа, оранжевый — нужно внимание.
    var indicatorColor: NSColor {
        switch self {
        case .ready, .message: .systemGreen
        case .recording: .systemRed
        case .processing, .modelDownloading, .modelPreparing: .systemBlue
        case .noMicrophone, .needAccessibility, .modelMissing, .modelFailed: .systemOrange
        }
    }
}

/// Размытие того, что лежит за окном (вибрантность как у боковых панелей системных окон).
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

extension Color {
    /// Цвет, который сам выбирает вариант под светлую или тёмную тему.
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    static let windowFill = Color(nsColor: .windowBackgroundColor)
    /// Карточка светлее фона в обеих темах: белая на светлом, чуть подсвеченная на тёмном.
    static let cardFill = dynamic(light: .controlBackgroundColor, dark: NSColor(white: 1, alpha: 0.06))
    /// Край карточки: заливка уже отделяет её от фона, рамка лишь чуть подчёркивает.
    static let cardEdge = Color.primary.opacity(0.05)
    static let hairline = Color.primary.opacity(0.09)
    /// Второстепенный текст и значки: чуть контрастнее системного `.secondary`, который на стекле читается плохо.
    static let secondaryText = dynamic(light: NSColor(white: 0, alpha: 0.62), dark: NSColor(white: 1, alpha: 0.64))
    /// Клавиша и её нижний «бортик».
    static let keyFace = dynamic(light: .white, dark: NSColor(white: 0.29, alpha: 1))
    static let keyLip = dynamic(light: NSColor(white: 0, alpha: 0.16), dark: NSColor(white: 0, alpha: 0.38))
}

// MARK: стекло

extension View {
    /// Градиентный признак «переключения» поверх стекла: само стекло берёт только один сплошной цвет
    /// тонировки (`Glass.tint` принимает `Color`, не градиент), поэтому градиент кладётся сверху —
    /// лёгкая заливка по всей форме плюс более заметная кромка, иначе на маленьком элементе не видно.
    /// `fill` — сила заливки; большим элементам (клавиша) нужна слабее, иначе они выглядят сплошной плашкой.
    func switchGlow<S: InsettableShape>(_ shape: S, fill: Double = 0.22) -> some View {
        overlay(shape.fill(Brand.switchFill.opacity(fill)))
            .overlay(shape.strokeBorder(Brand.switchFill, lineWidth: 1.75))
    }

    /// `switchGlow`, но только когда `selected` — для мест, где один и тот же вид рисует и выбранное,
    /// и невыбранное состояние (клавиша триггера).
    @ViewBuilder
    func switchGlow<S: InsettableShape>(_ shape: S, when selected: Bool, fill: Double = 0.22) -> some View {
        if selected { switchGlow(shape, fill: fill) } else { self }
    }

    /// Кнопка приложения: Liquid Glass на macOS 26+, на старых системах обычная системная.
    /// Главная (`prominent`) закрашена акцентом.
    @ViewBuilder
    func appButton(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            // Акцент окрашивает только главную кнопку; у остальных он превратил бы стекло в сплошной цвет.
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass).tint(nil) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}

/// Стекло приложения: `.interactive()` даёт то самое поведение Liquid Glass: при нажатии элемент упруго
/// сжимается, по нему бежит блик от точки касания, а на отпускании он пружинит.
@available(macOS 26, *)
extension Glass {
    static func liquid(tint: Color? = nil, interactive: Bool = true) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        return interactive ? glass.interactive() : glass
    }
}

/// Контейнер стекла: стеклянные элементы внутри перетекают друг в друга (морфинг по `glassEffectID`).
/// На старых системах контейнера нет, содержимое показывается как есть.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    private let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Упругий отклик на нажатие для элементов без собственного стекла (и для всего на macOS 14–25):
/// элемент проседает, форма подсвечивается, а при отпускании он пружинит с лёгким перелётом.
struct LiquidPressStyle<S: InsettableShape>: ButtonStyle {
    let shape: S
    var scale: CGFloat = 0.96
    var highlight = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background { shape.fill(Color.primary.opacity(highlight && configuration.isPressed ? 0.10 : 0)) }
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Иконка приложения из файла в бандле: системный кэш иконок после пересборки бывает устаревшим.
@MainActor var appIcon: NSImage {
    Bundle.main.image(forResource: "AppIcon") ?? NSApp.applicationIconImage
}

/// Плавные пружины приложения: одни и те же во всём интерфейсе, чтобы движение ощущалось единым.
enum Motion {
    /// Смена выбора, перемещение подсветки: пружина с лёгким перелётом — читается как «переключение», не просто фейд.
    static let select = Animation.spring(response: 0.34, dampingFraction: 0.74)
    /// Появление и исчезновение элементов.
    static let appear = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Переход между вкладками.
    static let pane = Animation.smooth(duration: 0.3)
    /// Нажатие и отпускание: быстрая пружина с перелётом, как у интерактивного стекла.
    static let press = Animation.spring(response: 0.3, dampingFraction: 0.52)
}

// MARK: карточки

/// Группа строк на скруглённой подложке, как в Системных настройках. Строки разделяет `CardDivider`.
struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.cardEdge, lineWidth: 0.5))
    }
}

struct CardDivider: View {
    var body: some View {
        Rectangle().fill(Color.hairline).frame(height: 0.5).padding(.leading, 14)
    }
}

/// Строка внутри карточки: единые отступы.
struct CardRow<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Карточка с подписью сверху и пояснением снизу.
struct Block<Content: View>: View {
    let title: String?
    let footer: String?
    /// Без подложки: для элементов со своим видом (клавиши, сегменты), чтобы не было «карточки в карточке».
    let plain: Bool
    private let content: Content

    init(title: String? = nil, footer: String? = nil, plain: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.plain = plain
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                    .padding(.horizontal, 4)
            }
            if plain { content } else { Card { content } }
            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: мелочи

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        Circle().fill(color).frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// Переносит элементы на следующую строку, как текст.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: usedWidth, height: y + rowHeight), origins)
    }
}
