import Foundation
import AppKit
import OptuneCore

/// Lightweight update checker. Hits the GitHub Releases API to discover the
/// latest tag, compares it to the current bundle version, and offers to open
/// the download page if there's a newer release.
///
/// Not full Sparkle (no XPC, no signature verification). For a real product we
/// would link the framework + ship an EdDSA-signed appcast — but for an open-
/// source repo where users grab DMGs from the Releases page, this is enough.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var status: Status = .idle

    enum Status: Equatable {
        case idle
        case checking
        case upToDate(version: String)
        case available(latest: String, url: URL, notes: String)
        case error(String)
    }

    private let releasesURL = URL(string: "https://api.github.com/repos/Sanjays2402/optune/releases/latest")!

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"
    }

    /// Schedule periodic checks (once on launch, then daily).
    func scheduleAutomaticChecks() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await self?.checkNow()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 24 * 3_600 * 1_000_000_000)
                await self?.checkNow()
            }
        }
    }

    func checkNow() async {
        guard SettingsStore.shared.app.autoUpdateEnabled else { return }
        status = .checking
        do {
            var req = URLRequest(url: releasesURL)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("optune-update-checker", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoder = JSONDecoder()
            let release = try decoder.decode(Release.self, from: data)
            let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            if isVersion(latest, newerThan: currentVersion) {
                status = .available(
                    latest: latest,
                    url: URL(string: release.html_url) ?? releasesURL,
                    notes: release.body ?? ""
                )
            } else {
                status = .upToDate(version: currentVersion)
            }
        } catch {
            status = .error("\(error.localizedDescription)")
        }
    }

    /// Open the GitHub Release page for the user to grab the new DMG.
    func openLatestRelease() {
        if case .available(_, let url, _) = status {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Version compare

    /// Returns true iff `a > b`. Delegates to `OptuneCore.SemverCompare`,
    /// which strips pre-release/build suffixes and compares numeric segments.
    private func isVersion(_ a: String, newerThan b: String) -> Bool {
        SemverCompare.isVersion(a, newerThan: b)
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let body: String?
    }
}
