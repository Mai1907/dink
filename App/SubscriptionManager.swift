import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
  var isPlus = false
  var isConfigured = false
  var isLoading = false
  var monthlyPackage: Package?
  var message: String?

  init() {
    #if DEBUG
    let keyName = "DinkRevenueCatTestAPIKey"
    #else
    let keyName = "DinkRevenueCatProductionAPIKey"
    #endif
    if let key = Bundle.main.object(forInfoDictionaryKey: keyName) as? String,
       !key.isEmpty, !key.hasPrefix("$(") {
      Purchases.configure(withAPIKey: key)
      isConfigured = true
    }
  }

  func refresh() async {
    guard isConfigured else {
      message = "Test store setup is pending. You can continue with the free demo."
      return
    }
    do {
      async let info = Purchases.shared.customerInfo()
      async let offerings = Purchases.shared.offerings()
      isPlus = try await info.entitlements.all["dink_plus"]?.isActive == true
      monthlyPackage = try await offerings.current?.monthly
      message = nil
    } catch {
      message = "Plans are temporarily unavailable. Try again shortly."
    }
  }

  func purchaseMonthly() async {
    guard let monthlyPackage else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let purchase = try await Purchases.shared.purchase(package: monthlyPackage)
      isPlus = purchase.customerInfo.entitlements.all["dink_plus"]?.isActive == true
      if !purchase.userCancelled && !isPlus {
        message = "The purchase completed, but Plus has not activated yet. Try Restore Purchases."
      }
    } catch {
      message = "The purchase did not complete. Please try again."
    }
  }

  func restore() async {
    guard isConfigured else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let info = try await Purchases.shared.restorePurchases()
      isPlus = info.entitlements.all["dink_plus"]?.isActive == true
      message = isPlus ? nil : "No active Dink Plus subscription was found."
    } catch {
      message = "Purchases could not be restored right now."
    }
  }
}
