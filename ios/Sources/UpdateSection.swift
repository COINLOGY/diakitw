import SwiftUI

struct UpdateSection: View {
    @ObservedObject var checker: UpdateChecker
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Обновления").font(.headline)
            Picker("Канал", selection: Binding(get: { checker.channel }, set: { checker.choose($0) })) {
                Text("Preview").tag("preview"); Text("Stable").tag("stable")
            }.pickerStyle(.segmented)
            Text(checker.status).font(.caption)
            if let offer = checker.offer {
                Text(verbatim: offer.notes).font(.caption)
                Button("Открыть страницу релиза") { openURL(offer.releasePage) }
                Button("Позже") { checker.later() }
            }
            Button("Проверить обновления") { checker.check() }.disabled(checker.checking)
            Text("Unsigned-сборка: этот экран только уведомляет. Установка на iPhone отсюда невозможна; нужны отдельная подпись и разрешённый способ распространения. Автоустановки нет.").font(.caption)
            Text("GitHub получает обычный HTTPS-запрос без метрик и параметров: при активном приложении, не чаще раза в 24 ч; вручную — минимум 60 с. Хеш и подпись загруженного файла здесь не проверяются.").font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
