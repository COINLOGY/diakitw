import SwiftUI
import MacdirCore

/// Container-wide statfs snapshot, never a breakdown of the folder scan.
struct DiskCapacityOverview: View {
 let snapshot: ResourceSnapshot
 let scan: ScanResult?
 private var occupied: Int64? { snapshot.diskOccupied }
 private var fraction: Double? {
  GaugeScale.fraction(occupied.map(Double.init), maximum: snapshot.diskTotal.map(Double.init))
 }
 private var caveat: String {
  "Занятость файловой системы — не сумма папок. " +
   (scan.map { $0.root.complete
     ? "Обход выбранной папки завершён; его логические размеры не равны занятым блокам APFS."
     : "Обход выбранной папки частичный (≥); его логические размеры не описывают весь диск."
   } ?? "Обход папок ещё не завершён.")
 }
 var body: some View {
  HStack(alignment: .center, spacing: 12) {
   VStack(alignment: .leading, spacing: 3) {
    Label("Обзор ёмкости", systemImage: "internaldrive").font(.caption.weight(.semibold))
    Text(snapshot.diskType == "apfs" ? "APFS · общий контейнер" : "\(snapshot.diskType) · файловая система")
     .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    Text(snapshot.diskMount).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
   }.frame(width: 166, alignment: .leading)
   VStack(alignment: .leading, spacing: 5) {
    Text("\(bytes(occupied)) из \(bytes(snapshot.diskTotal)) занято")
     .font(.system(.headline, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
    GeometryReader { geometry in
     ZStack(alignment: .leading) {
      Capsule().fill(.secondary.opacity(0.24))
      if let fraction { Capsule().fill(InstrumentTheme.lime).frame(width: geometry.size.width * fraction) }
     }
    }.frame(height: 8).accessibilityLabel("Занято \(MetricPresentation.utilization(occupied, total: snapshot.diskTotal)); свободно \(bytes(snapshot.validatedDiskFree))")
    HStack(spacing: 10) {
     Text("Занято: \(bytes(occupied))")
     Spacer(minLength: 4)
     Text("Свободно: \(bytes(snapshot.validatedDiskFree))")
    }.font(.caption2.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
    Text("Снимок \(snapshot.diskMeasured?.formatted(date: .abbreviated, time: .standard) ?? "замер недоступен")")
     .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
   }.frame(maxWidth: .infinity, alignment: .leading)
  }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
   .background(InstrumentTheme.panel, in: RoundedRectangle(cornerRadius: 12))
   .help(caveat)
   .accessibilityElement(children: .contain)
 }
}
