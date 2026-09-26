import Foundation

protocol CheckupService {
  func analyze(photos: [Data]) async -> CheckupResult
}

struct MockCheckupService: CheckupService {
  var resultIndex: Int = 1

  static var defaultResult: CheckupResult { results[1] }

  static var results: [CheckupResult] {[
    CheckupResult(
      severityBand: .healthy, plaque: 0, tartar: 0, gumHealth: 0,
      redFlags: [],
      findings: ["Teeth appear clean in these photos", "Gums appear pink and even"],
      homeCarePlan: ["Keep brushing 3 times a week", "Offer dental chews daily", "Check again in 30 days"]
    ),
    CheckupResult(
      severityBand: .early, plaque: 1, tartar: 1, gumHealth: 0,
      redFlags: [],
      findings: ["Mild buildup may be present on the upper left molars", "Gums appear pink and healthy"],
      homeCarePlan: ["Brush 3 times a week", "Offer dental chews daily", "Recheck in 30 days"]
    ),
    CheckupResult(
      severityBand: .moderate, plaque: 2, tartar: 2, gumHealth: 1,
      redFlags: ["Visible gum redness is worth showing a vet"],
      findings: ["Buildup may be present along the back teeth", "One gum area appears slightly red"],
      homeCarePlan: ["Arrange a dental check with your vet", "Brush gently as tolerated", "Watch for changes and recheck soon"]
    )
  ]}

  func analyze(photos: [Data]) async -> CheckupResult {
    try? await Task.sleep(for: .milliseconds(2500))
    return Self.results[min(max(resultIndex, 0), Self.results.count - 1)]
  }
}
