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
 var body: some View {
  VStack(alignment: .leading, spacing: 10) {
   HStack {
    Label("Обзор ёмкости", systemImage: "internaldrive").font(.headline)
    Spacer(minLength: 0)
    Text(snapshot.diskType == "apfs" ? "APFS · общий контейнер" : "\(snapshot.diskType) · файловая система")
     .font(.caption).foregroundStyle(.secondary)
   }
   Text("\(bytes(occupied)) из \(bytes(snapshot.diskTotal)) занято")
    .font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
   GeometryReader { geometry in
    ZStack(alignment: .leading) {
     Capsule().fill(.secondary.opacity(0.24))
     if let fraction { Capsule().fill(InstrumentTheme.lime).frame(width: geometry.size.width * fraction) }
    }
   }.frame(height: 10).accessibilityLabel("Занято \(MetricPresentation.utilization(occupied, total: snapshot.diskTotal)); свободно \(bytes(snapshot.validatedDiskFree))")
   HStack {
    Text("Занято: \(bytes(occupied))")
    Spacer(minLength: 8)
    Text("Свободно: \(bytes(snapshot.validatedDiskFree))")
   }.font(.caption.monospacedDigit())
   Text("Снимок \(snapshot.diskMount) · \(snapshot.diskMeasured?.formatted(date: .abbreviated, time: .standard) ?? "замер недоступен")")
    .font(.caption2).foregroundStyle(.secondary)
   Text("Занятость файловой системы — не сумма папок. \(scan.map { $0.root.complete ? "Обход выбранной папки завершён; его логические размеры не равны занятым блокам APFS." : "Обход выбранной папки частичный (≥); его логические размеры не описывают весь диск." } ?? "Обход папок ещё не завершён.")")
    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
  }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
   .background(InstrumentTheme.panel, in: RoundedRectangle(cornerRadius: 14))
   .accessibilityElement(children: .contain)
 }
}
