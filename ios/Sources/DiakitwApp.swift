import SwiftUI

private enum Theme {
    static let background = Color(red: 0.078, green: 0.102, blue: 0.129)
    static let panel = Color(red: 0.118, green: 0.165, blue: 0.208)
    static let border = Color(red: 0.22, green: 0.29, blue: 0.34)
    static let cyan = Color(red: 0.298, green: 0.749, blue: 1)
    static let lime = Color(red: 0.68, green: 0.91, blue: 0.18)
    static let red = Color(red: 1, green: 0.43, blue: 0.49)
    static let muted = Color(red: 0.70, green: 0.77, blue: 0.82)
    static func color(_ band: Dial.Band) -> Color {
        switch band { case .green: return lime; case .blue: return cyan; case .red: return red; case .unknown: return muted }
    }
}

struct Instrument: View {
    let value: Double?
    let maximum: Double
    var battery = false
    var speedColor: Color? = nil
    var percent = true
    var body: some View {
        Canvas { context, size in
            let geometry = Dial.geometry(width: size.width, height: size.height)
            let radius = geometry.radius, tailClearance = geometry.tailClearance
            let center = CGPoint(x: size.width / 2, y: geometry.centerY)
            func point(_ f: Double, _ r: Double) -> CGPoint {
                let p = Dial.point(fraction: f)
                return CGPoint(x: center.x + p.x * r, y: center.y + p.y * r)
            }
            for tick in 0...40 {
                let f = Double(tick) / 40
                let color = speedColor ?? Theme.color(Dial.band(f, battery: battery))
                var band = Path(); band.move(to: point(f, radius)); band.addLine(to: point(f, radius - 5 * 7/9))
                context.stroke(band, with: .color(color), lineWidth: 2)
                if tick % 2 == 0 {
                    var mark = Path(); mark.move(to: point(f, radius * 111/114)); mark.addLine(to: point(f, radius * (tick % 20 == 0 ? 103 : 108)/114))
                    context.stroke(mark, with: .color(Theme.muted), lineWidth: tick % 20 == 0 ? 1.5 : 1)
                }
            }
            let labels = percent ? ["0%", "50%", "100%"] : ["0", String(format: "%.0f", maximum/2), String(format: "%.0f", maximum)]
            // Label gutters: endpoints below baseline; midpoint above the arc, never over ticks.
            context.draw(Text(labels[0]).font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.muted), at: CGPoint(x: center.x-radius, y: center.y+tailClearance+12))
            context.draw(Text(labels[1]).font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.muted), at: CGPoint(x: center.x, y: 8))
            context.draw(Text(labels[2]).font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.muted), at: CGPoint(x: center.x+radius, y: center.y+tailClearance+12))
            if let f = Dial.fraction(value, total: maximum) {
                let color = speedColor ?? Theme.color(Dial.band(f, battery: battery))
                let vertices = Dial.needle(fraction: f, radius: radius)
                var needle = Path()
                for (index, p) in vertices.enumerated() {
                    let vertex = CGPoint(x: center.x+p.x, y: center.y+p.y)
                    if index == 0 { needle.move(to: vertex) } else { needle.addLine(to: vertex) }
                }
                needle.closeSubpath()
                context.fill(needle, with: .color(color))
                let hub = CGRect(x: center.x-4, y: center.y-4, width: 8, height: 8)
                context.fill(Path(ellipseIn: hub), with: .color(Theme.background))
                context.stroke(Path(ellipseIn: hub.insetBy(dx: 0.5, dy: 0.5)), with: .color(color), lineWidth: 1)
            }
        }
        .frame(width: 145, height: 105)
        .accessibilityHidden(true)
    }
}

private struct MetricCard: View {
    let title: String
    let number: String
    let detail: String
    let value: Double?
    var maximum: Double = 1
    var battery = false
    var speedColor: Color? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let tint = speedColor ?? Theme.color(Dial.band(Dial.fraction(value, total: maximum), battery: battery))
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { reading(tint); instrument }
            } else {
                HStack(spacing: 4) { reading(tint).frame(maxWidth: .infinity, alignment: .leading); instrument }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
    private var instrument: some View { Instrument(value: value, maximum: maximum, battery: battery, speedColor: speedColor, percent: speedColor == nil) }
    private func reading(_ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.medium))
            Text(number).font(.system(.title2, design: .monospaced).weight(.semibold)).foregroundStyle(tint).minimumScaleFactor(0.8).lineLimit(1)
            Text(detail).font(.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor private final class Presentation: ObservableObject {
    @Published var help = false
    @Published var confirm = false
}

struct ContentView: View {
    @StateObject private var model = Monitor()
    @StateObject private var presentation = Presentation()
    @StateObject private var updates = UpdateChecker()
    @Environment(\.scenePhase) private var phase
    private func number(_ value: Double?, suffix: String = "") -> String {
        guard let value else { return "Н/Д" }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value) + suffix
    }
    private var ramFraction: Double? { Dial.fraction(model.appRAM, total: model.physicalRAM) }
    private var storageFraction: Double? { Dial.fraction(model.diskUsed, total: model.diskTotal ?? 0) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image("Brand").resizable().frame(width: 38, height: 38).accessibilityHidden(true)
                    Text("diakitw").font(.largeTitle.weight(.semibold))
                    Spacer()
                    Button { presentation.help = true } label: { Image(systemName: "questionmark.circle").font(.title2).frame(width: 48, height: 48) }.accessibilityLabel("О показаниях и приватности")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 12)], spacing: 12) {
                    MetricCard(title: "RAM приложения", number: number(model.appRAM.map { $0 / 1_048_576 }, suffix: " MiB"), detail: number(ramFraction.map { $0*100 }, suffix: "% физической RAM") + "\nВсего " + number(model.physicalRAM / 1_073_741_824, suffix: " GiB"), value: ramFraction)
                    MetricCard(title: "Том приложения", number: number(storageFraction.map { $0*100 }, suffix: "%"), detail: number(model.diskUsed.map { $0 / 1_073_741_824 }) + " / " + number(model.diskTotal.map { $0 / 1_073_741_824 }, suffix: " GiB"), value: storageFraction)
                    MetricCard(title: "Батарея", number: number(model.charge.map { $0*100 }, suffix: "%"), detail: model.power, value: model.charge, battery: true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("IP · \(model.country) · \(model.ip)").font(.subheadline.monospaced()).textSelection(.enabled)
                    if let city = model.geo?.city { Text("≈ " + city).font(.subheadline) }
                    HStack {
                        Text(model.ipStatus)
                        if let date = model.ipDate { Text(date, style: .time) }
                    }.font(.caption).foregroundStyle(Theme.muted)
                    Text("Страна выхода/VPN, не GPS").font(.caption).foregroundStyle(Theme.muted)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 12)], spacing: 12) {
                    MetricCard(title: "↓ Загрузка", number: number(model.download), detail: "Мбит/с • диапазон прибора", value: model.download, maximum: Dial.speedScale(model.download), speedColor: Theme.lime)
                    MetricCard(title: "↑ Отправка", number: number(model.upload), detail: "Мбит/с • диапазон прибора", value: model.upload, maximum: Dial.speedScale(model.upload), speedColor: Theme.cyan)
                }
                Text(model.speedStatus).font(.caption).foregroundStyle(Theme.muted)
                Button {
                    if model.running { model.cancelSpeed() } else { presentation.confirm = true }
                } label: {
                    Text(model.running ? "Отменить тест" : "Старт теста интернета")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                }.buttonStyle(.borderedProminent).tint(Theme.cyan).foregroundStyle(Theme.background)
                UpdateSection(checker: updates)
                Text("0.5.4 · iOS").font(.caption2).foregroundStyle(Theme.muted)
            }.padding(16).frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
        }
        .background(Theme.background).foregroundStyle(.white).preferredColorScheme(.dark)
        .onAppear { model.setForeground(phase == .active); updates.setForeground(phase == .active) }
        .onChange(of: phase) { model.setForeground($0 == .active); updates.setForeground($0 == .active) }
        .onDisappear { model.setForeground(false); updates.setForeground(false) }
        .alert("Тест использует интернет", isPresented: $presentation.confirm) {
            Button("Отмена", role: .cancel) {}
            Button("Старт") { model.startSpeed() }
        } message: {
            Text("8 MiB загрузки + 2 MiB синтетической отправки, до 44 секунд. Служебный трафик и буферы сети — сверх этого объёма. Возможна плата оператора. Сервер Cloudflare; VPN влияет на результат. Отмена или уход из приложения останавливает тест.")
        }
        .sheet(isPresented: $presentation.help) {
            NavigationStack {
                ScrollView {
                    Text(Self.helpText).padding().frame(maxWidth: .infinity, alignment: .leading)
                }.navigationTitle("О показаниях").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { presentation.help = false } } }
            }.preferredColorScheme(.dark)
        }
    }
    static let helpText = """
    RAM — резидентная память только процесса diakitw (mach_task_basic_info). Доля рассчитана от физической RAM устройства, а не от лимита приложения. Общая занятость RAM, системный CPU и SWAP на iOS здесь не измеряются.

    Хранилище — занято/всего для файлового тома домашнего каталога приложения (systemSize − systemFreeSize). Это не размер файлов diakitw, не здоровье SSD и не гарантированно доступное место для записи. iOS и APFS могут иначе учитывать очищаемое место.

    Батарея — заряд и состояние из UIDevice. Н/Д означает отсутствие показания; это не 0%. Обновление локальных показаний каждые 2 секунды только на переднем плане.

    IP и приблизительная география — 2ip через EMCx: GET https://aia.emcx.pro/diakitw-api/geo без параметров и токена в приложении. EMCx и 2ip получают IP выхода; серверный кеш 1 час, общая квота 300/день и 9000/месяц. Запросы только на переднем плане, с задержкой 1.5 с и интервалом не менее 60 с. Только при ошибке используется прежний api.country.is. IP и страна заменяются одним снимком; отсутствующие город и координаты не выдумываются. При полной ошибке данные очищаются. Это выход в интернет/VPN, не GPS. Смена VPN обнаруживается периодическим обновлением, не мгновенно. Геолокация устройства не запрашивается.

    Скорость — два отдельных последовательных запроса к speed.cloudflare.com только после Старт и подтверждения. Загрузка 8 MiB, отправка 2 MiB искусственных данных, ответ отправки до 4 KiB. Пользовательские файлы не читаются и не отправляются. Средняя полезная скорость = биты / полное время запроса, включая установку соединения и ответ. Короткий тест может занижать пропускную способность; это не гарантированный тариф провайдера. Результаты показываются после каждого завершённого направления. Шкала прибора адаптивная, не процент загрузки канала. Ping, jitter и потери пакетов не измеряются.

    Каждый запрос имеет срок до 22 секунд, ограничение сохраняемого ответа, без перенаправлений, cookies и дискового кеша. Лимит полезных данных не является точной квотой трафика оператора: TLS, заголовки и буферизация добавляют байты. Незавершённые результаты не выдумываются. Сеть отменяется при уходе в фон.
    """
}

@main struct DiakitwApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
