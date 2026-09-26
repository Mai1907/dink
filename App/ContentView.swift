import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]
  @Query private var pets: [Pet]
  @AppStorage("hasShownFirstScanPaywall") private var hasShownFirstScanPaywall = false
  @AppStorage("lastFreeScanDate") private var lastFreeScanDate = Date.distantPast
  @State private var mockResultIndex = 0
  @State private var screen: Screen = .home
  @State private var hingePose: HingePose = .unknown
  @State private var hingeAngle: Double?
  @State private var demoOverride = false
  @State private var currentScan: ScanRecord?
  @State private var resultReturnScreen: Screen = .home
  @State private var showDeleteError = false
  @State private var subscription = SubscriptionManager()
  @State private var showPaywall = false
  @State private var paywallReason: PaywallReason = .upgrade
  @State private var showPetEditor = false
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var petNameDraft = ""
  @State private var showDemoBand = false

  private var pet: Pet? { pets.first }
  private var completedScans: [ScanRecord] { scans.filter(\.isComplete) }
  private var draft: ScanRecord? { scans.first(where: { !$0.isComplete && !$0.photos.isEmpty }) }
  private var hasUsedFreeScanThisMonth: Bool {
    Calendar.current.isDate(lastFreeScanDate, equalTo: .now, toGranularity: .month) ||
      completedScans.contains { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
  }
  private var canStartLiveScan: Bool { hingePose.isPropped || hingePose == .unsupported }

  var body: some View {
    Group {
      if #available(iOS 27.1, *) {
        appContent.onHingeChange { _, context in
          updateHinge(context)
        }
      } else {
        appContent
      }
    }
    .tint(Color(red: 0.06, green: 0.57, blue: 0.53))
    .task {
      if pets.isEmpty { modelContext.insert(Pet()) }
      await subscription.refresh()
    }
    .sheet(isPresented: $showPaywall) {
      PaywallView(
        subscription: subscription,
        onContinueFree: {
          let shouldStartDemo = paywallReason == .scanLimit
          showPaywall = false
          if shouldStartDemo { startScan(demo: true) }
        },
        onClose: { showPaywall = false }
      )
    }
    .sheet(isPresented: $showPetEditor) {
      petEditor
    }
    .alert("Couldn't delete scan", isPresented: $showDeleteError) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("Please try again.")
    }
    .onChange(of: selectedPhoto) { _, item in
      Task {
        if let data = try? await item?.loadTransferable(type: Data.self) {
          pet?.photoData = data
          try? modelContext.save()
        }
      }
    }
  }

  private var appContent: some View {
    NavigationStack {
      Group {
        switch screen {
        case .home: home
        case .setup: setup
        case .scanning:
          if let currentScan {
            ScanView(
              hingePose: hingePose,
              demoOverride: demoOverride,
              initialCaptures: currentScan.photos,
              onProgress: { photos in
                currentScan.photos = photos
                try? modelContext.save()
              },
              onComplete: { photos in
                currentScan.photos = photos
                try? modelContext.save()
                screen = .analyzing
                Task { await analyze(photos) }
              },
              onClose: { screen = .home }
            )
          }
        case .analyzing: analyzing
        case .results:
          if let currentScan, currentScan.isComplete {
            ResultsView(scan: currentScan, petPhotoData: pet?.photoData, isPlus: subscription.isPlus,
                        onUpgrade: {
                          paywallReason = .upgrade
                          showPaywall = true
                        },
                        onSave: { screen = .home },
                        onDelete: { deleteScan(currentScan) })
          }
        case .history:
          HistoryView(scans: completedScans, isPlus: subscription.isPlus,
                      onUpgrade: {
                        paywallReason = .upgrade
                        showPaywall = true
                      },
                      onSelect: { scan in
                        currentScan = scan
                        resultReturnScreen = .history
                        screen = .results
                      })
        }
      }
      .toolbar {
        if screen == .setup || screen == .history || screen == .results {
          ToolbarItem(placement: .topBarLeading) {
            Button("Home", systemImage: "chevron.left") { screen = .home }
              .labelStyle(.iconOnly)
          }
        }
      }
    }
  }

  private var home: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Image("DinkLogo")
          .resizable()
          .scaledToFit()
          .frame(width: 175, height: 50, alignment: .leading)
          .accessibilityLabel("Dink")
          .accessibilityAddTraits(.isHeader)
        VStack(alignment: .leading, spacing: 16) {
          Image("DinkIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 94, height: 94)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 12)
            .onLongPressGesture {
              mockResultIndex = (mockResultIndex + 1) % MockCheckupService.results.count
              showDemoBand = true
              Task {
                try? await Task.sleep(for: .seconds(2))
                showDemoBand = false
              }
            }
            .accessibilityLabel("Dink dental check-up. Long press to cycle demo results")
          Text("Check your pet's teeth in 60 seconds.")
            .font(.title.bold())
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
          if showDemoBand {
            Text("Demo band: \(MockCheckupService.results[mockResultIndex].severityBand.rawValue)")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity)
          }
          if hingePose == .closed || hingePose == .fullyOpen || hingePose == .adjust {
            VStack(alignment: .leading, spacing: 8) {
              Text("Place your Duo on a table")
                .font(.headline)
              Text("Open it like a laptop to about 45°, with the inner screen facing your pet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              FoldGuideView()
                .frame(height: 108)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
          }
          Button("Start dental check-up", systemImage: "camera.viewfinder") {
            if !subscription.isPlus && hasUsedFreeScanThisMonth {
              paywallReason = .scanLimit
              showPaywall = true
            } else {
              screen = .setup
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .frame(maxWidth: .infinity)
          .disabled(!canStartLiveScan)
          foldStatus
        }

        if let draft {
          Button("Resume unfinished scan", systemImage: "arrow.clockwise") {
            currentScan = draft
            demoOverride = false
            screen = .setup
          }
          .buttonStyle(.bordered)
          .disabled(!canStartLiveScan)
        }

        petSection

        if completedScans.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text("Your first check-up").font(.headline)
            Label("Prop your Duo halfway", systemImage: "iphone.gen3")
            Label("Light up the mouth", systemImage: "sun.max.fill")
            Label("Let Dink capture four views", systemImage: "camera.fill")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(18)
          .background(.background, in: RoundedRectangle(cornerRadius: 8))
        } else {
          HStack {
            Text("Past scans").font(.title3.bold())
            Spacer()
            Button("View history", systemImage: "chevron.right") { screen = .history }
              .labelStyle(.titleAndIcon)
          }
          ForEach(subscription.isPlus ? Array(completedScans.prefix(3)) : Array(completedScans.prefix(1))) { scan in
            Button {
              currentScan = scan
              resultReturnScreen = .home
              screen = .results
            } label: {
              scanRow(scan)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .frame(maxWidth: 760)
      .frame(maxWidth: .infinity)
      .padding(20)
    }
    .background(Color(.systemGroupedBackground))
    .safeAreaInset(edge: .bottom) {
      if !canStartLiveScan {
        Button("Try sample scan", systemImage: "play.fill") { startScan(demo: true) }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .frame(maxWidth: 300)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
          .background(.regularMaterial)
      }
    }
    .navigationTitle("")
    .toolbar(.hidden, for: .navigationBar)
  }

  @ViewBuilder
  private var foldStatus: some View {
    if hingePose != .unsupported {
      HStack(spacing: 10) {
        Image(systemName: hingePose.isPropped ? "checkmark.circle.fill" : "iphone.gen3")
          .foregroundStyle(hingePose.isPropped ? Color.green : Color.accentColor)
        Text(hingePose.isPropped ? "Ready to scan" : "Set your Duo to 45°–120° to start")
          .font(.subheadline.weight(.medium))
        Spacer(minLength: 4)
        if let hingeAngle {
          Text("\(Int(hingeAngle.rounded()))°")
            .font(.subheadline.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .combine)
    }
  }

  private var petSection: some View {
    Button {
      petNameDraft = pet?.name ?? "My pet"
      showPetEditor = true
    } label: {
      HStack(spacing: 14) {
        petPortrait
        VStack(alignment: .leading, spacing: 4) {
          Text(pet?.name ?? "My pet").font(.headline)
          Text("Pet profile").font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
      }
      .padding(12)
      .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private var petPortrait: some View {
    Group {
      if let data = pet?.photoData, let image = UIImage(data: data) {
        Image(uiImage: image).resizable().scaledToFill()
      } else if let url = Bundle.main.url(forResource: "dog-pp", withExtension: "jpg"),
                let image = UIImage(contentsOfFile: url.path) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Image(systemName: "pawprint.fill").resizable().scaledToFit().padding(15)
      }
    }
    .frame(width: 58, height: 58)
    .clipShape(Circle())
    .foregroundStyle(.tint)
    .background(.quaternary, in: Circle())
  }

  private func scanRow(_ scan: ScanRecord) -> some View {
    HStack(spacing: 12) {
      if let data = scan.photoData, let image = UIImage(data: data) {
        Image(uiImage: image)
          .resizable().scaledToFill()
          .frame(width: 56, height: 56)
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

  private var setup: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Image(systemName: "iphone.gen3")
          .font(.system(size: 64))
          .foregroundStyle(.tint)
          .frame(maxWidth: .infinity)
        Text("Set up the scan")
          .font(.largeTitle.bold())
        Text(setupInstruction)
          .font(.title2.weight(.medium))
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
          .padding(20)
          .background(.background, in: RoundedRectangle(cornerRadius: 8))
        if hingePose == .propped {
          Button("Begin scan", systemImage: "camera.viewfinder") { startScan(demo: false) }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if hingePose == .unsupported {
          Button("Continue handheld", systemImage: "camera.viewfinder") {
            startScan(demo: false)
          }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        Button("Try sample scan", systemImage: "play.fill") { startScan(demo: true) }
          .buttonStyle(.bordered)
      }
      .frame(maxWidth: 600)
      .frame(maxWidth: .infinity)
      .padding(24)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Scan setup")
  }

  private var setupInstruction: String {
    switch hingePose {
    case .closed, .unknown: "Open your Duo to start scanning."
    case .fullyOpen: "Fold it halfway, like a laptop, and set it on the floor facing your pet."
    case .propped: "Perfect. Kneel behind your pet and lift its lip."
    case .adjust: "Adjust the fold to 45°–120° so the screen faces your pet."
    case .unsupported: "Hold your phone steady near your pet's mouth. The flashlight will help with lighting."
    }
  }

  private var analyzing: some View {
    VStack(spacing: 24) {
      Image("DinkIcon")
        .resizable()
        .scaledToFit()
        .frame(width: 94, height: 94)
      Text("Reviewing the photos…")
        .font(.title.bold())
      ProgressView()
        .controlSize(.large)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Analyzing")
  }

  private var petEditor: some View {
    NavigationStack {
      Form {
        TextField("Pet name", text: $petNameDraft)
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
          Label("Choose pet photo", systemImage: "photo")
        }
      }
      .navigationTitle("Pet profile")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            pet?.name = petNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My pet" : petNameDraft
            try? modelContext.save()
            showPetEditor = false
          }
        }
      }
    }
  }

  private func startScan(demo: Bool) {
    demoOverride = demo
    if currentScan == nil || currentScan?.isComplete == true {
      let record = ScanRecord(petName: pet?.name ?? "My pet")
      modelContext.insert(record)
      currentScan = record
      try? modelContext.save()
    }
    screen = .scanning
  }

  private func analyze(_ photos: [Data]) async {
    let result = await MockCheckupService(resultIndex: mockResultIndex).analyze(photos: photos)
    guard let currentScan else { return }
    currentScan.finish(with: result)
    if !subscription.isPlus {
      lastFreeScanDate = currentScan.date
      for previous in completedScans where previous.id != currentScan.id {
        modelContext.delete(previous)
      }
    }
    try? modelContext.save()
    resultReturnScreen = .home
    screen = .results
    if !hasShownFirstScanPaywall {
      hasShownFirstScanPaywall = true
      paywallReason = .postScan
      showPaywall = true
    }
  }

  private func deleteScan(_ scan: ScanRecord) {
    do {
      if !subscription.isPlus && Calendar.current.isDate(scan.date, equalTo: .now, toGranularity: .month) {
        lastFreeScanDate = scan.date
      }
      modelContext.delete(scan)
      try modelContext.save()
      currentScan = nil
      screen = resultReturnScreen
    } catch {
      modelContext.rollback()
      showDeleteError = true
    }
  }

  @available(iOS 27.1, *)
  private func updateHinge(_ context: DeviceHingeContext) {
    guard let hinge = context.hinge else {
      hingePose = .unsupported
      hingeAngle = nil
      return
    }
    hingeAngle = hinge.angle.degrees
    if hinge.status == .closed {
      hingePose = .closed
    } else if hinge.status == .fullyOpen {
      hingePose = .fullyOpen
    } else if hinge.status == .partiallyOpen {
      hingePose = HingePose.scanningAngleRange.contains(hinge.angle.degrees) ? .propped : .adjust
    } else {
      hingePose = .adjust
    }
    if screen == .setup && hingePose == .propped { startScan(demo: false) }
  }
}

private enum Screen: Equatable {
  case home
  case setup
  case scanning
  case analyzing
  case results
  case history
}

private enum PaywallReason {
  case scanLimit
  case postScan
  case upgrade
}
