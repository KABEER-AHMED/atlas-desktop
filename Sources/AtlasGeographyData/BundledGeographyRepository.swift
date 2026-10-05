import Foundation
import AtlasDesktopCore
import os

/// Loads the dataset that ships inside the app bundle.
///
/// Decoding runs off the main actor (`Task.detached`): ~180 countries
/// and ~10k vertices is fast, but it is still file I/O plus validation
/// and has no business blocking the first frame.
public struct BundledGeographyRepository: GeographyRepository {
    public static let resourceName = "atlas-countries"
    public static let resourceExtension = "json"

    private static let logger = Logger(subsystem: "com.atlasdesktop.app", category: "geography")

    private let bundle: Bundle

    /// The data module's own resource bundle, where the generated
    /// asset is copied at build time.
    public static var resourceBundle: Bundle { .module }

    /// Defaults to the data module's resource bundle. A different
    /// bundle can be injected by tests.
    public init(bundle: Bundle? = nil) {
        self.bundle = bundle ?? Self.resourceBundle
    }

    public func load() async throws -> GeographyDataset {
        let fileName = "\(Self.resourceName).\(Self.resourceExtension)"

        guard let url = bundle.url(forResource: Self.resourceName, withExtension: Self.resourceExtension) else {
            Self.logger.error("Bundled geography resource not found: \(fileName, privacy: .public)")
            throw GeographyError.resourceMissing(name: fileName)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            Self.logger.error("Bundled geography resource unreadable: \(error.localizedDescription, privacy: .public)")
            throw GeographyError.resourceUnreadable(name: fileName, reason: error.localizedDescription)
        }

        return try await Task.detached(priority: .userInitiated) {
            try GeographyDecoder.decodeDataset(from: data)
        }.value
    }
}
