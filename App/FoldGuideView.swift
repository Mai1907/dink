import SwiftUI

struct FoldGuideView: View {
  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / 280, size.height / 140)
      context.translateBy(x: (size.width - 280 * scale) / 2, y: (size.height - 140 * scale) / 2)
      context.scaleBy(x: scale, y: scale)

      var table = Path()
      table.move(to: CGPoint(x: 20, y: 122))
      table.addLine(to: CGPoint(x: 260, y: 122))
      context.stroke(table, with: .color(.secondary.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

      let casing = Color(red: 0.12, green: 0.46, blue: 0.42)
      let light = Color(red: 0.98, green: 0.97, blue: 0.93)
      context.fill(Path(roundedRect: CGRect(x: 46, y: 105, width: 176, height: 13), cornerRadius: 6), with: .color(casing))

      var upperHalf = Path()
      upperHalf.move(to: CGPoint(x: 210, y: 107))
      upperHalf.addLine(to: CGPoint(x: 133, y: 37))
      upperHalf.addQuadCurve(to: CGPoint(x: 140, y: 28), control: CGPoint(x: 129, y: 29))
      upperHalf.addLine(to: CGPoint(x: 222, y: 101))
      upperHalf.closeSubpath()
      context.fill(upperHalf, with: .color(casing))

      var innerScreen = Path()
      innerScreen.move(to: CGPoint(x: 136, y: 38))
      innerScreen.addLine(to: CGPoint(x: 210, y: 105))
      context.stroke(innerScreen, with: .color(light), style: StrokeStyle(lineWidth: 5, lineCap: .round))

      var lowerScreen = Path()
      lowerScreen.move(to: CGPoint(x: 54, y: 107))
      lowerScreen.addLine(to: CGPoint(x: 208, y: 107))
      context.stroke(lowerScreen, with: .color(light), style: StrokeStyle(lineWidth: 3, lineCap: .round))

      context.fill(Path(ellipseIn: CGRect(x: 208, y: 102, width: 14, height: 14)), with: .color(Color(red: 0.95, green: 0.66, blue: 0.23)))
    }
    .accessibilityHidden(true)
  }
}
