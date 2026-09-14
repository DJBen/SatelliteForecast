import SwiftUI

extension EnvironmentValues {
  /// Injectable storage location keeps file browsing and screenshot fixtures independent.
  @Entry var ephemerisDirectory: URL = FileManager.default.temporaryDirectory
}
