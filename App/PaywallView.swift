import RevenueCat
import SwiftUI

struct PaywallView: View {
  var subscription: SubscriptionManager
  var onContinueFree: () -> Void
  var onClose: () -> Void

  @Environment(\.horizontalSizeClass) private var widthClass

  var body: some View {
    NavigationStack {
      ScrollView {
        Group {
          if widthClass == .regular {
            HStack(alignment: .top, spacing: 28) {
              visual
              plans
            }
          } else {
            VStack(alignment: .leading, spacing: 20) {
              visual
              plans
            }
          }
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
        .padding(24)
      }
      .background(Color(.systemGroupedBackground))
      .safeAreaInset(edge: .bottom) {
        Button(action: onContinueFree) {
          Text("Continue for free")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.regularMaterial)
      }
      .navigationTitle("Dink Plus")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close", systemImage: "xmark") { onClose() }
            .labelStyle(.iconOnly)
        }
      }
      .task { await subscription.refresh() }
    }
  }

  private var visual: some View {
    VStack(alignment: .leading, spacing: 18) {
      Image(systemName: "pawprint.fill")
        .font(.system(size: 58))
        .foregroundStyle(.tint)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("A brighter picture of their dental health")
        .font(.title.bold())
        .fixedSize(horizontal: false, vertical: true)
      Text("Keep every check-up together and share clear notes with your vet.")
        .font(.body)
        .foregroundStyle(.secondary)
      Label("Unlimited scans", systemImage: "infinity")
      Label("Full history and trends", systemImage: "chart.xyaxis.line")
      Label("Share scans with your vet", systemImage: "square.and.arrow.up")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(24)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }

  private var plans: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Choose your plan")
        .font(.title2.bold())
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Dink Plus monthly").font(.headline)
          Text("Cancel anytime").font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        Text(subscription.monthlyPackage?.storeProduct.localizedPriceString ?? "Monthly")
          .font(.headline)
      }
      .padding(16)
      .background(.background, in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.tint, lineWidth: 2))

      Button {
        Task { await subscription.purchaseMonthly() }
      } label: {
        Text("Continue with Dink Plus")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(subscription.monthlyPackage == nil || subscription.isLoading)

      Button("Restore Purchases") {
        Task { await subscription.restore() }
      }
      .frame(maxWidth: .infinity)
      .disabled(!subscription.isConfigured || subscription.isLoading)

      if subscription.isLoading { ProgressView().frame(maxWidth: .infinity) }
      if let message = subscription.message {
        Text(message)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Text("Free includes one check-up per month and your latest result.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(24)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}
