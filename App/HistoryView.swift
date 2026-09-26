import Charts
import SwiftUI
import UIKit

struct HistoryView: View {
  var scans: [ScanRecord]
  var isPlus: Bool
  var onUpgrade: () -> Void
  var onSelect: (ScanRecord) -> Void

  private var visibleScans: [ScanRecord] {
    isPlus ? scans : Array(scans.prefix(1))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if !isPlus {
          Button("Unlock full history", systemImage: "lock.open") { onUpgrade() }
            .buttonStyle(.borderedProminent)
        }
        if visibleScans.count > 1 {
          Chart(visibleScans.reversed()) { scan in
            LineMark(
              x: .value("Date", scan.date),
              y: .value("Band", SeverityBand(rawValue: scan.severityBand)?.score ?? 0)
            )
            PointMark(
              x: .value("Date", scan.date),
              y: .value("Band", SeverityBand(rawValue: scan.severityBand)?.score ?? 0)
            )
          }
          .chartYScale(domain: 0...3)
          .chartYAxis {
            AxisMarks(values: [0, 1, 2, 3]) { value in
              AxisGridLine()
              AxisValueLabel {
                if let score = value.as(Int.self) {
                  Text(SeverityBand.allCases.first(where: { $0.score == score })?.rawValue ?? "")
                }
              }
            }
          }
          .frame(height: 220)
          .padding(16)
          .background(.background, in: RoundedRectangle(cornerRadius: 8))
        }
        if visibleScans.isEmpty {
          ContentUnavailableView("No scans yet", systemImage: "stethoscope", description: Text("Your completed check-ups will appear here."))
        } else {
          LazyVStack(spacing: 10) {
            ForEach(visibleScans) { scan in
              Button { onSelect(scan) } label: {
                HStack(spacing: 14) {
                  if let data = scan.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                      .resizable()
                      .scaledToFill()
                      .frame(width: 60, height: 60)
                      .clipShape(RoundedRectangle(cornerRadius: 6))
                  }
                  VStack(alignment: .leading, spacing: 4) {
                    Text(scan.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                    Text(scan.severityBand).font(.subheadline).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .frame(maxWidth: 800)
      .frame(maxWidth: .infinity)
      .padding(20)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("History")
  }
}
