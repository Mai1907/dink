import SwiftUI
import UIKit

enum HingePose: Equatable {
  case unknown
  case closed
  case fullyOpen
  case propped
  case adjust
  case unsupported

  var isPropped: Bool { self == .propped }
}

struct ScanView: View {
  var hingePose: HingePose
  var demoOverride: Bool
  var initialCaptures: [Data]
  var onProgress: ([Data]) -> Void
  var onComplete: ([Data]) -> Void
  var onClose: () -> Void

  @AppStorage("forceSampleVideo") private var forceSampleVideo = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var camera = CameraService()
  @State private var brightness = BrightnessKeeper()
  @State private var captures: [Data]
  @State private var isCapturing = false
  @State private var lastCapture = Date.now
  @State private var flash = false
  @State private var warmLight = false
  @State private var treatPulse = false

  private var handheld: Bool { hingePose == .unsupported }
  private var canCapture: Bool {
    demoOverride || handheld || hingePose.isPropped
  }

  init(hingePose: HingePose, demoOverride: Bool, initialCaptures: [Data],
       onProgress: @escaping ([Data]) -> Void,
       onComplete: @escaping ([Data]) -> Void,
       onClose: @escaping () -> Void) {
    self.hingePose = hingePose
    self.demoOverride = demoOverride
    self.initialCaptures = initialCaptures
    self.onProgress = onProgress
    self.onComplete = onComplete
    self.onClose = onClose
    _captures = State(initialValue: initialCaptures)
  }

  var body: some View {
    Group {
      if handheld || horizontalSizeClass == .compact {
        previewPanel
      } else if #available(iOS 27.1, *) {
        ArrangementView {
          previewPanel
        } secondary: {
          lightPanel
        }
        .arrangementViewStyle(.overlay)
        .background(warmLight ? Color(red: 1, green: 0.94, blue: 0.79) : .white)
      } else {
        VStack(spacing: 0) {
          lightPanel
          previewPanel
        }
      }
    }
    .ignoresSafeArea()
    .background(Color.black)
    .toolbar(.hidden, for: .navigationBar)
    .sensoryFeedback(.impact(weight: .medium), trigger: captures.count)
    .task(id: forceSampleVideo) {
      await camera.start(handheld: handheld, forceSample: forceSampleVideo || demoOverride)
      lastCapture = .now
      while !Task.isCancelled && captures.count < ScanTarget.allCases.count {
        try? await Task.sleep(for: .milliseconds(200))
        guard canCapture, camera.isReady, !isCapturing else { continue }
        guard Date.now.timeIntervalSince(lastCapture) >= 3.5 else { continue }
        guard camera.isSampleMode || (camera.isBright && camera.isSteady) else { continue }
        captureNow()
      }
    }
    .onChange(of: canCapture, initial: true) { _, active in
      if active && !handheld && !camera.isSampleMode {
        brightness.raise()
      } else if active && !handheld {
        brightness.raise()
      } else {
        brightness.restore()
      }
    }
    .onDisappear {
      brightness.restore()
      camera.stop()
    }
  }

  private var lightPanel: some View {
    GeometryReader { geometry in
      ZStack {
        (warmLight ? Color(red: 1, green: 0.94, blue: 0.79) : .white)
        Image(systemName: "pawprint.fill")
          .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.18, weight: .medium))
          .foregroundStyle(Color(red: 0.17, green: 0.69, blue: 0.62).opacity(0.8))
          .scaleEffect(treatPulse ? 1.14 : 0.85)
          .opacity(treatPulse ? 1 : 0.65)
          .position(x: geometry.size.width * 0.64, y: geometry.size.height * 0.34)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.bouncy(duration: 1.1).repeatForever(autoreverses: true)) {
          treatPulse = true
        }
      }
    }
    .accessibilityLabel("Mouth light panel")
  }

  private var previewPanel: some View {
    GeometryReader { geometry in
      ZStack {
        if camera.isSampleMode {
          SamplePreview()
        } else {
          CameraPreview(camera: camera)
        }

        RoundedRectangle(cornerRadius: 22)
          .stroke(Color.mint.opacity(0.85), lineWidth: 3)
          .frame(width: geometry.size.width * 0.52, height: geometry.size.height * 0.34)
          .shadow(color: .mint.opacity(0.45), radius: 20)
          .opacity(canCapture && Date.now.timeIntervalSince(lastCapture) > 1.2 ? 0.8 : 0.25)
          .allowsHitTesting(false)

        if flash {
          Color.white.opacity(0.72)
            .transition(.opacity)
            .allowsHitTesting(false)
        }

        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top) {
            checklist
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
              Button("Close", systemImage: "xmark") { onClose() }
                .labelStyle(.iconOnly)
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.55), in: Circle())
              proppedBadge
            }
          }
          Spacer(minLength: 8)
          if !canCapture {
            Text(hingePose == .closed ? "Open your Duo to continue" : "Adjust the fold")
              .font(.title3.bold())
              .foregroundStyle(.white)
              .padding(16)
              .frame(maxWidth: .infinity)
              .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
          }
          HStack(spacing: 10) {
            Button(warmLight ? "Cool light" : "Warm light", systemImage: warmLight ? "sun.max" : "sun.max.fill") {
              warmLight.toggle()
            }
            .disabled(handheld)
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.62))
            Spacer(minLength: 2)
            Button("Capture now", systemImage: "camera.fill") { captureNow() }
              .labelStyle(.iconOnly)
              .font(.title3)
              .frame(width: 50, height: 50)
              .background(.mint, in: Circle())
              .foregroundStyle(.black)
              .disabled(!canCapture || isCapturing)
          }
          Text(prompt)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.72), in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, topControlInset(in: geometry))
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 34))
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
  }

  private var checklist: some View {
    VStack(alignment: .leading, spacing: 7) {
      ForEach(ScanTarget.allCases, id: \.self) { target in
        HStack(spacing: 7) {
          Image(systemName: captures.count > target.rawValue ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(captures.count > target.rawValue ? .mint : .white)
          Text(target.title)
            .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
      }
    }
    .foregroundStyle(.white)
    .padding(12)
    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Captured \(captures.count) of 4 dental views")
  }

  private var proppedBadge: some View {
    Text(canCapture ? "Propped ✓" : "Adjust the fold")
      .font(.caption.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 11)
      .padding(.vertical, 7)
      .background(canCapture ? Color.teal.opacity(0.92) : Color.orange.opacity(0.9), in: Capsule())
      .onLongPressGesture {
        forceSampleVideo.toggle()
        camera.stop()
      }
      .accessibilityLabel(canCapture ? "Propped. Long press to toggle sample video" : "Adjust the fold. Long press to toggle sample video")
  }

  private var prompt: String {
    if !canCapture { return "Keep the mouth in view" }
    if !camera.isSampleMode && !camera.isBright { return "Move closer to the light" }
    if !camera.isSampleMode && !camera.isSteady { return "Hold the phone steady" }
    let index = min(captures.count, ScanTarget.allCases.count - 1)
    return ScanTarget.allCases[index].prompt
  }

  private func topControlInset(in geometry: GeometryProxy) -> CGFloat {
    if #available(iOS 27.1, *) {
      let occlusions = geometry.reservedRegions(kind: .occlusion)
      let fold = geometry.reservedRegions(kind: .division)
      let nearbyRegions = (occlusions + fold).filter {
        $0.frame.maxY > 0 && $0.frame.minY < 100
      }
      let lowerEdge = nearbyRegions.map { $0.frame.maxY }.max() ?? 0
      return max(geometry.safeAreaInsets.top, lowerEdge) + 12
    }
    return geometry.safeAreaInsets.top + 12
  }

  private func captureNow() {
    guard canCapture, !isCapturing, captures.count < 4 else { return }
    isCapturing = true
    camera.capture { data in
      isCapturing = false
      lastCapture = .now
      guard let data else { return }
      captures.append(data)
      onProgress(captures)
      withAnimation(.smooth(duration: 0.12)) { flash = true }
      Task {
        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.smooth(duration: 0.2)) { flash = false }
      }
      if captures.count == 4 { onComplete(captures) }
    }
  }
}

private enum ScanTarget: Int, CaseIterable {
  case front
  case left
  case right
  case gums

  var title: String {
    switch self {
    case .front: "Front teeth"
    case .left: "Left side"
    case .right: "Right side"
    case .gums: "Gums"
    }
  }

  var prompt: String {
    switch self {
    case .front: "Lift the lip higher"
    case .left: "Show the left side"
    case .right: "Show the right side"
    case .gums: "Tilt the phone toward the mouth"
    }
  }
}

private final class BrightnessKeeper {
  private var screen: UIScreen?
  private var oldValue: CGFloat?

  func raise() {
    guard oldValue == nil,
          let screen = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.screen else { return }
    self.screen = screen
    oldValue = screen.brightness
    screen.brightness = 1
  }

  func restore() {
    if let screen, let oldValue { screen.brightness = oldValue }
    screen = nil
    oldValue = nil
  }
}
