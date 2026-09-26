import Foundation
import SwiftData

@Model
final class Pet {
  var id: UUID
  var name: String
  @Attribute(.externalStorage) var photoData: Data?

  init(name: String = "My pet", photoData: Data? = nil) {
    self.id = UUID()
    self.name = name
    self.photoData = photoData
  }
}

@Model
final class ScanRecord {
  var id: UUID
  var date: Date
  var petName: String
  var severityBand: String
  var isComplete: Bool
  @Attribute(.externalStorage) var photoData: Data?
  @Attribute(.externalStorage) var photosArchive: Data
  var resultData: Data

  init(petName: String) {
    self.id = UUID()
    self.date = .now
    self.petName = petName
    self.severityBand = ""
    self.isComplete = false
    self.photoData = nil
    self.photosArchive = Data()
    self.resultData = Data()
  }

  var photos: [Data] {
    get { (try? PropertyListDecoder().decode([Data].self, from: photosArchive)) ?? [] }
    set {
      photosArchive = (try? PropertyListEncoder().encode(newValue)) ?? Data()
      photoData = newValue.first
    }
  }

  func finish(with result: CheckupResult) {
    severityBand = result.severityBand.rawValue
    resultData = (try? JSONEncoder().encode(result)) ?? Data()
    isComplete = true
    date = .now
  }

  var result: CheckupResult {
    (try? JSONDecoder().decode(CheckupResult.self, from: resultData)) ?? MockCheckupService.defaultResult
  }
}

enum SeverityBand: String, Codable, CaseIterable {
  case healthy = "Healthy"
  case early = "Early"
  case moderate = "Moderate"
  case advanced = "Advanced"

  var score: Int {
    switch self {
    case .healthy: 0
    case .early: 1
    case .moderate: 2
    case .advanced: 3
    }
  }
}

struct CheckupResult: Codable, Equatable {
  var severityBand: SeverityBand
  var plaque: Int
  var tartar: Int
  var gumHealth: Int
  var redFlags: [String]
  var findings: [String]
  var homeCarePlan: [String]
}
