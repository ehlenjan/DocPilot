import SwiftUI
import AppKit

@MainActor
final class AtlasEditPanelController {

    static let shared =
        AtlasEditPanelController()

    private var panel:
        NSPanel?

    private init() {}

    // MARK: - Show

    func show(
        document: DocumentRecord,
        availableCompanies: [String],
        initialRecipientArea: ArchiveArea,
        initialSender: String,
        initialDocumentType: DocumentType,
        initialDate: Date?,
        destinationURL: Binding<URL?>,
        initialFilename: String,
        archiveViewModel: ArchiveViewModel,
        isWorking: Bool,
        onSaveAndArchive: @escaping (AtlasEditValues) -> Void
    ) {

        close()

        let contentView =
            AtlasEditView(
                document:
                    document,

                availableCompanies:
                    availableCompanies,

                initialRecipientArea:
                    initialRecipientArea,

                initialSender:
                    initialSender,

                initialDocumentType:
                    initialDocumentType,

                initialDate:
                    initialDate,

                destinationURL:
                    destinationURL,

                initialFilename:
                    initialFilename,

                archiveViewModel:
                    archiveViewModel,

                isWorking:
                    isWorking,

                onCancel: {
                    [weak self] in

                    self?.close()
                },

                onSaveAndArchive: {
                    values in

                    onSaveAndArchive(
                        values
                    )
                }
            )

        let hostingController =
            NSHostingController(
                rootView:
                    contentView
            )

        let newPanel =
            NSPanel(
                contentRect:
                    NSRect(
                        x: 0,
                        y: 0,
                        width: 620,
                        height: 760
                    ),

                styleMask: [
                    .titled,
                    .closable,
                    .resizable,
                    .utilityWindow
                ],

                backing:
                    .buffered,

                defer:
                    false
            )

        newPanel.title =
            "Atlas – Angaben korrigieren"

        newPanel.contentViewController =
            hostingController

        newPanel.isFloatingPanel =
            true

        newPanel.level =
            .floating

        newPanel.hidesOnDeactivate =
            false

        newPanel.isMovableByWindowBackground =
            false

        newPanel.collectionBehavior = [
            .fullScreenAuxiliary,
            .moveToActiveSpace
        ]

        newPanel.minSize =
            NSSize(
                width: 520,
                height: 650
            )

        // MARK: - Remember Position + Size

        newPanel.setFrameAutosaveName(
            "AtlasEditPanel"
        )

        // Nur wenn noch keine gespeicherte
        // Fensterposition existiert, einmal
        // sinnvoll platzieren.
        if !hasStoredFrame() {

            positionInitially(
                newPanel
            )
        }

        newPanel.makeKeyAndOrderFront(
            nil
        )

        NSApp.activate(
            ignoringOtherApps:
                true
        )

        panel =
            newPanel
    }

    // MARK: - Close

    func close() {

        guard let panel
        else {

            return
        }

        panel.orderOut(
            nil
        )

        panel.close()

        self.panel =
            nil
    }

    // MARK: - Initial Position

    private func positionInitially(
        _ panel: NSPanel
    ) {

        guard let screen =
            NSScreen.main
        else {

            panel.center()

            return
        }

        let visibleFrame =
            screen.visibleFrame

        let panelSize =
            panel.frame.size

        // Rechts oben platzieren,
        // damit das PDF möglichst sichtbar bleibt.
        let x =
            visibleFrame.maxX
            - panelSize.width
            - 30

        let y =
            visibleFrame.maxY
            - panelSize.height
            - 30

        panel.setFrameOrigin(
            NSPoint(
                x: x,
                y: y
            )
        )
    }

    // MARK: - Stored Frame Check

    private func hasStoredFrame() -> Bool {

        let key =
            "NSWindow Frame AtlasEditPanel"

        guard let stored =
            UserDefaults.standard
                .string(
                    forKey:
                        key
                )
        else {

            return false
        }

        return !stored.isEmpty
    }
}
