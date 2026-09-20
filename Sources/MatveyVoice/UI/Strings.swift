import Foundation

/// Единый способ достать строку интерфейса из таблицы `UI`.
func ui(_ key: String, _ args: CVarArg...) -> String {
    let text = String(localized: String.LocalizationValue(key), table: "UI", bundle: .main)
    return args.isEmpty ? text : String(format: text, arguments: args)
}
