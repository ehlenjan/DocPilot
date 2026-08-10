import Foundation

struct VisualSenderLearningEntry: Codable, Identifiable {

    let id: UUID

    /// Firma, die der Benutzer für dieses
    /// visuelle Merkmal bestätigt hat.
    let company: String

    /// Visuelle Signatur des Logo-/Kopfbereichs.
    ///
    /// Anders als ein normaler String-/Bild-Hash
    /// kann diese später über eine Distanz mit
    /// ähnlichen Dokumentköpfen verglichen werden.
    let signature: VisualFeatureSignature

    /// Wann diese Zuordnung erstmals
    /// gelernt wurde.
    let createdAt: Date

    /// Wann sie zuletzt bestätigt wurde.
    var lastConfirmedAt: Date

    /// Anzahl der Bestätigungen durch
    /// den Benutzer.
    var confirmationCount: Int

    init(
        id: UUID = UUID(),
        company: String,
        signature: VisualFeatureSignature,
        createdAt: Date = Date(),
        lastConfirmedAt: Date = Date(),
        confirmationCount: Int = 1
    ) {
        self.id = id

        self.company =
            company.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        self.signature =
            signature

        self.createdAt =
            createdAt

        self.lastConfirmedAt =
            lastConfirmedAt

        self.confirmationCount =
            max(
                confirmationCount,
                1
            )
    }

    // MARK: - Confirmation

    mutating func confirm() {

        confirmationCount += 1

        lastConfirmedAt =
            Date()
    }

    // MARK: - Confidence

    var confidence: Double {

        switch confirmationCount {

        case 3...:
            return 0.95

        case 2:
            return 0.80

        default:
            return 0.60
        }
    }

    // MARK: - Automatic Use

    /// Erst nach drei Bestätigungen darf Atlas
    /// diese visuelle Zuordnung ohne Rückfrage
    /// als Absender verwenden.
    var canUseAutomatically: Bool {

        confirmationCount >= 3
    }
}
