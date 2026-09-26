import SwiftUI
import UIKit

struct ResultsView: View {
  var scan: ScanRecord
  var isPlus: Bool
  var onUpgrade: () -> Void
  var onSave: () -> Void

  @Environment(\.horizontalSizeClass) private var widthClass
  @State private var showShare = false

  var body: some View {
    ScrollView {
      Group {
        if widthClass == .regular {
          HStack(alignment: .top, spacing: 24) {
            photoPanel
            findingsPanel
          }
        } else {
          VStack(alignment: .leading, spacing: 24) {
            photoPanel
            findingsPanel
          }
        }
      }
      .frame(maxWidth: 980)
      .frame(maxWidth: .infinity)
      .padding(20)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Check-up result")
    .sheet(isPresented: $showShare) {
      ShareSheet(items: shareItems)
    }
  }

  private var photoPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(scan.petName)
        .font(.title2.bold())
      Text(scan.date.formatted(date: .abbreviated, time: .shortened))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      GeometryReader { geometry in
        ZStack {
          if let data = scan.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: geometry.size.width, height: geometry.size.height)
              .clipped()
          } else {
            Rectangle().fill(.quaternary)
          }
          RoundedRectangle(cornerRadius: 16)
            .stroke(.mint, lineWidth: 3)
            .frame(width: geometry.size.width * 0.48, height: geometry.size.height * 0.26)
            .shadow(color: .mint.opacity(0.7), radius: 12)
          VStack {
            Spacer()
            Text("Area reviewed")
              .font(.caption.bold())
              .foregroundStyle(.white)
              .padding(8)
              .background(.black.opacity(0.7), in: Capsule())
              .padding(12)
          }
        }
      }
      .aspectRatio(1.25, contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      Text("Photo-based screening only. A vet can assess concerns in person.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var findingsPanel: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Overall band").font(.subheadline).foregroundStyle(.secondary)
          Text(scan.result.severityBand.rawValue)
            .font(.largeTitle.bold())
        }
        Spacer()
        Image(systemName: "stethoscope")
          .font(.largeTitle)
          .foregroundStyle(.tint)
      }
      .padding(18)
      .background(.background, in: RoundedRectangle(cornerRadius: 8))

      HStack(spacing: 8) {
        scoreBadge("Plaque", value: scan.result.plaque)
        scoreBadge("Tartar", value: scan.result.tartar)
        scoreBadge("Gums", value: scan.result.gumHealth)
      }

      section("What the photos may show", items: scan.result.findings, symbol: "eye")
      if !scan.result.redFlags.isEmpty {
        section("Worth showing a vet", items: scan.result.redFlags, symbol: "exclamationmark.triangle")
      }
      section("Home-care plan", items: scan.result.homeCarePlan.enumerated().map { "\($0.offset + 1). \($0.element)" }, symbol: "heart.text.clipboard")

      HStack {
        Button("Share with vet", systemImage: "square.and.arrow.up") {
          if isPlus { showShare = true } else { onUpgrade() }
        }
        .buttonStyle(.bordered)
        Button("Save scan", systemImage: "checkmark") { onSave() }
          .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func scoreBadge(_ title: String, value: Int) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text("\(value) / 3").font(.headline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
  }

  private func section(_ title: String, items: [String], symbol: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol).font(.headline)
      ForEach(items, id: \.self) { item in
        Text(item)
          .font(.subheadline)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
  }

  private var shareItems: [Any] {
    let result = scan.result
    let summary = "Dink check-up for \(scan.petName), \(scan.date.formatted(date: .abbreviated, time: .omitted))\nBand: \(result.severityBand.rawValue)\n\(result.findings.joined(separator: "\n"))\nHome care: \(result.homeCarePlan.joined(separator: "; "))\nPhoto-based screening only; please assess in person."
    let images: [Any] = scan.photos.compactMap { UIImage(data: $0) }
    return images + [summary]
  }
}

private struct ShareSheet: UIViewControllerRepresentable {
  var items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
