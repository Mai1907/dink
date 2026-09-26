import AVFoundation
import SwiftUI
import UIKit

struct SamplePreview: View {
  @State private var isZoomed = false

  var body: some View {
    Group {
      if let url = Bundle.main.url(forResource: "pet_sample", withExtension: "mp4") {
        LoopingSampleVideo(url: url)
      } else if let url = Bundle.main.url(forResource: "pet_sample_still", withExtension: "png"),
                let image = UIImage(contentsOfFile: url.path) {
        GeometryReader { geometry in
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(isZoomed ? 1.035 : 1)
            .clipped()
            .onAppear {
              withAnimation(.smooth(duration: 2).repeatForever(autoreverses: true)) {
                isZoomed = true
              }
            }
        }
      } else {
        Rectangle()
          .fill(.black)
          .overlay {
            Image(systemName: "pawprint.fill")
              .font(.system(size: 90))
              .foregroundStyle(.white.opacity(0.3))
          }
      }
    }
    .accessibilityLabel("Sample view of a dog's teeth")
  }
}

private struct LoopingSampleVideo: UIViewRepresentable {
  var url: URL

  func makeUIView(context: Context) -> LoopingVideoSurface {
    LoopingVideoSurface(url: url)
  }

  func updateUIView(_ view: LoopingVideoSurface, context: Context) { }
}

private final class LoopingVideoSurface: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
  private var player = AVQueuePlayer()
  private var looper: AVPlayerLooper?

  init(url: URL) {
    super.init(frame: .zero)
    player.isMuted = true
    looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    let videoLayer = layer as! AVPlayerLayer
    videoLayer.player = player
    videoLayer.videoGravity = .resizeAspectFill
    player.play()
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  deinit { player.pause() }
}
