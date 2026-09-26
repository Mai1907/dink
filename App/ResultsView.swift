import SwiftUI
import UIKit

struct ResultsView: View {
  var scan: ScanRecord
  var petPhotoData: Data?
  var isPlus: Bool
  var hingePose: HingePose
  var onUpgrade: () -> Void
  var onSave: () -> Void
  var onDelete: () -> Void

  @Environment(\.horizontalSizeClass) private var widthClass
  @State private var showShare = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    Group {
      if hingePose.isPropped {
        if #available(iOS 27.1, *) {
          hingeReport
        } else {
          standardReport
        }
      } else {
        standardReport
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Check-up result")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Delete scan", systemImage: "trash") {
          showDeleteConfirmation = true
        }
        .labelStyle(.iconOnly)
      }
    }
    .alert("Delete this scan?", isPresented: $showDeleteConfirmation) {
      Button("Delete Scan", role: .destructive, action: onDelete)
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("The saved photos and result will be removed. This can't be undone.")
    }
    .sheet(isPresented: $showShare) {
      ShareSheet(items: shareItems)
    }
  }

  private var standardReport: some View {
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
  }

  @available(iOS 27.1, *)
  private var hingeReport: some View {
    ArrangementView {
      ScrollView {
        hingeEvidencePanel
          .frame(maxWidth: 800)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 32)
      }
    } secondary: {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          findingsPanel
          Text("Photo-based screening only. A vet can assess concerns in person.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 800)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 32)
      }
    }
    .arrangementViewStyle(.split.axes(.vertical))
  }

  private var photoPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(scan.petName)
        .font(.title2.bold())
      Text(scan.date.formatted(date: .abbreviated, time: .shortened))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      GeometryReader { geometry in
        if let profileImage {
          Image(uiImage: profileImage)
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        } else {
          Rectangle().fill(.quaternary)
        }
      }
      .aspectRatio(1.5, contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Profile photo of \(scan.petName)")

      HStack {
        Text("Captured scan views").font(.headline)
        Spacer()
        Text("\(scan.photos.count) photos")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.top, 8)
      scanPhotoGrid(aspectRatio: 1.3)
      Text("Photo-based screening only. A vet can assess concerns in person.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var hingeEvidencePanel: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 14) {
        Group {
          if let profileImage {
            Image(uiImage: profileImage)
              .resizable()
              .scaledToFill()
          } else {
            Image(systemName: "pawprint.fill")
              .resizable()
              .scaledToFit()
              .padding(14)
              .foregroundStyle(.tint)
          }
        }
        .frame(width: 62, height: 62)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Profile photo of \(scan.petName)")
        VStack(alignment: .leading, spacing: 4) {
          Text(scan.petName).font(.title2.bold())
          Text(scan.date.formatted(date: .abbreviated, time: .shortened))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      HStack {
        Text("Captured scan views").font(.headline)
        Spacer()
        Text("\(scan.photos.count) photos")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      scanPhotoGrid(aspectRatio: 1.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func scanPhotoGrid(aspectRatio: CGFloat) -> some View {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
      ForEach(Array(scan.photos.enumerated()), id: \.offset) { index, data in
        if let image = UIImage(data: data) {
          GeometryReader { geometry in
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: geometry.size.width, height: geometry.size.height)
              .clipped()
              .overlay(alignment: .bottomLeading) {
                Text("View \(index + 1)")
                  .font(.caption.bold())
                  .foregroundStyle(.white)
                  .padding(6)
                  .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                  .padding(8)
              }
          }
          .aspectRatio(aspectRatio, contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Captured scan view \(index + 1)")
        }
      }
    }
  }

  private var profileImage: UIImage? {
    if let petPhotoData, let image = UIImage(data: petPhotoData) { return image }
    guard let url = Bundle.main.url(forResource: "dog-pp", withExtension: "jpg") else { return nil }
    return UIImage(contentsOfFile: url.path)
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
        Image("DinkIcon")
          .resizable()
          .scaledToFit()
          .frame(width: 40, height: 40)
      }
      .padding(18)
      .background(.background, in: RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 8) {
        Text("Photo scores · higher is better")
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(spacing: 8) {
          scoreBadge("Plaque", concern: scan.result.plaque)
          scoreBadge("Tartar", concern: scan.result.tartar)
          scoreBadge("Gums", concern: scan.result.gumHealth)
        }
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

  private func scoreBadge(_ title: String, concern: Int) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text("\(max(0, min(3, 3 - concern))) / 3").font(.headline)
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
