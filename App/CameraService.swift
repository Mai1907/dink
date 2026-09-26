@preconcurrency import AVFoundation
import AVKit
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CameraService {
  var isSampleMode = true
  var isBright = true
  var isSteady = true
  var isReady = false

  @ObservationIgnored var session = AVCaptureSession()
  @ObservationIgnored private var photoOutput = AVCapturePhotoOutput()
  @ObservationIgnored private var frameSampler: FrameSampler?
  @ObservationIgnored private var directionCoordinator: AVCaptureDeviceDirectionCoordinator?
  @ObservationIgnored private var activeDevice: AVCaptureDevice?
  @ObservationIgnored private var photoCompletion: ((Data?) -> Void)?
  @ObservationIgnored private var handheld = false
  @ObservationIgnored private var sampleFrameGenerator: AVAssetImageGenerator?
  @ObservationIgnored private var sampleDuration: TimeInterval = 0
  @ObservationIgnored private var sampleStartDate = Date.now

  func start(handheld: Bool, forceSample: Bool) async {
    self.handheld = handheld
    #if targetEnvironment(simulator)
    await prepareSampleMode()
    return
    #else
    if forceSample {
      await prepareSampleMode()
      return
    }
    let authorization = AVCaptureDevice.authorizationStatus(for: .video)
    let allowed: Bool
    if authorization == .authorized {
      allowed = true
    } else if authorization == .notDetermined {
      allowed = await AVCaptureDevice.requestAccess(for: .video)
    } else {
      allowed = false
    }
    guard allowed else {
      await prepareSampleMode()
      return
    }
    configure(device: preferredDevice())
    isSampleMode = !session.inputs.isEmpty ? false : true
    if isSampleMode {
      await prepareSampleMode()
    } else {
      isReady = true
      let captureSession = session
      DispatchQueue.global(qos: .userInitiated).async { captureSession.startRunning() }
    }
    #endif
  }

  func stop() {
    if session.isRunning {
      let captureSession = session
      DispatchQueue.global(qos: .userInitiated).async { captureSession.stopRunning() }
    }
    if let activeDevice, activeDevice.hasTorch, activeDevice.torchMode == .on {
      try? activeDevice.lockForConfiguration()
      activeDevice.torchMode = .off
      activeDevice.unlockForConfiguration()
    }
    directionCoordinator = nil
  }

  func capture(_ completion: @escaping (Data?) -> Void) {
    if isSampleMode {
      let elapsed = Date.now.timeIntervalSince(sampleStartDate)
      let seconds = sampleDuration > 0 ? elapsed.truncatingRemainder(dividingBy: sampleDuration) : elapsed
      let time = CMTime(seconds: seconds, preferredTimescale: 600)
      let frame = sampleFrameGenerator.flatMap { try? $0.copyCGImage(at: time, actualTime: nil) }
      completion(frame.flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.88) }
                 ?? UIImage(named: "pet_sample_still")?.jpegData(compressionQuality: 0.88))
      return
    }
    photoCompletion = completion
    guard let frameSampler else { completion(nil); return }
    photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: frameSampler)
  }

  private func prepareSampleMode() async {
    isSampleMode = true
    sampleStartDate = .now
    sampleFrameGenerator = nil
    sampleDuration = 0
    if let url = Bundle.main.url(forResource: "video-dog-wm", withExtension: "mov") {
      let asset = AVURLAsset(url: url)
      if let duration = try? await asset.load(.duration) {
        sampleDuration = CMTimeGetSeconds(duration)
      }
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      sampleFrameGenerator = generator
    }
    isReady = true
  }

  func attachDirection(to view: UIView) {
    guard #available(iOS 27.1, *), !handheld, !isSampleMode else { return }
    directionCoordinator = AVCaptureDeviceDirectionCoordinator(
      view: view,
      deviceTypes: [.builtInInnerUltraWideCamera, .builtInOuterUltraWideCamera]
    ) { [weak self] directions in
      guard let self else { return }
      let inner = directions.forwardFacingDeviceDescriptors.first {
        $0.deviceType == .builtInInnerUltraWideCamera
      }
      if let inner,
         let device = AVCaptureDevice.devices(for: .video).first(where: { $0.uniqueID == inner.uniqueID }) {
        self.configure(device: device)
      }
    }
  }

  private func preferredDevice() -> AVCaptureDevice? {
    if handheld {
      return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    if #available(iOS 27.1, *),
       let inner = AVCaptureDevice.default(.builtInInnerUltraWideCamera, for: .video, position: .front) {
      return inner
    }
    return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
  }

  private func configure(device: AVCaptureDevice?) {
    guard let device, activeDevice?.uniqueID != device.uniqueID else { return }
    session.beginConfiguration()
    session.sessionPreset = .photo
    session.inputs.forEach { session.removeInput($0) }
    do {
      let input = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(input) else { session.commitConfiguration(); return }
      session.addInput(input)
      if session.outputs.isEmpty {
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let sampler = FrameSampler()
        sampler.onMetrics = { [weak self] bright, steady in
          Task { @MainActor in
            self?.isBright = bright
            self?.isSteady = steady
          }
        }
        sampler.onPhoto = { [weak self] data in
          Task { @MainActor in
            self?.photoCompletion?(data)
            self?.photoCompletion = nil
          }
        }
        frameSampler = sampler
        output.setSampleBufferDelegate(sampler, queue: DispatchQueue(label: "dink.frames"))
        if session.canAddOutput(output) { session.addOutput(output) }
      }
      activeDevice = device
      if handheld && device.hasTorch {
        try? device.lockForConfiguration()
        try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        device.unlockForConfiguration()
      }
    } catch { }
    session.commitConfiguration()
  }
}

private final class FrameSampler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
  var onMetrics: ((Bool, Bool) -> Void)?
  var onPhoto: ((Data?) -> Void)?
  private var previousSamples: [Double]?
  private var lastUpdate = Date.distantPast

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard Date().timeIntervalSince(lastUpdate) > 0.25,
          let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    lastUpdate = .now
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
    let bytes = base.assumingMemoryBound(to: UInt8.self)
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    var samples: [Double] = []
    for y in stride(from: height / 4, to: height * 3 / 4, by: 24) {
      for x in stride(from: width / 4, to: width * 3 / 4, by: 24) {
        let index = y * rowBytes + x * 4
        samples.append(0.0722 * Double(bytes[index]) +
                       0.7152 * Double(bytes[index + 1]) +
                       0.2126 * Double(bytes[index + 2]))
      }
    }
    let luma = samples.reduce(0, +) / Double(max(samples.count, 1))
    let steady = previousSamples.map { previous in
      zip(previous, samples).map { abs($0 - $1) }.reduce(0, +) /
        Double(max(samples.count, 1)) < 18
    } ?? false
    previousSamples = samples
    onMetrics?(luma > 65, steady)
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    onPhoto?(error == nil ? photo.fileDataRepresentation() : nil)
  }
}

struct CameraPreview: UIViewRepresentable {
  var camera: CameraService

  func makeUIView(context: Context) -> CameraPreviewSurface {
    let view = CameraPreviewSurface()
    view.previewLayer.session = camera.session
    camera.attachDirection(to: view)
    return view
  }

  func updateUIView(_ view: CameraPreviewSurface, context: Context) {
    view.previewLayer.session = camera.session
  }
}

final class CameraPreviewSurface: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

  override init(frame: CGRect) {
    super.init(frame: frame)
    previewLayer.videoGravity = .resizeAspectFill
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
