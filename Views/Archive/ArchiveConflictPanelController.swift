import SwiftUI
import AppKit

@MainActor
final class ArchiveConflictPanelController {

    static let shared =
        ArchiveConflictPanelController()

    private var panel:
        NSPanel?

    private init() {}

    // MARK: - Show

    func show(
        conflict: ArchiveConflict,
        onUseSuggestedFilename: @escaping () -> Void,
        onChangeFilename: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {

        close()

        let contentView =
            ArchiveConflictView(
                conflict:
                    conflict,

                onUseSuggestedFilename: {
                    [weak self] in

                    onUseSuggestedFilename()

                    self?.close()
                },

                onChangeFilename: {
                    [weak self] in

                    onChangeFilename()

                    self?.close()
                },

                onCancel: {
                    [weak self] in

                    onCancel()

                    self?.close()
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
                        width: 1100,
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
            "DocPilot – Archivkonflikt"

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
                width:
                    900,
                height:
                    620
            )

        // MARK: - Remember Position + Size

        newPanel.setFrameAutosaveName(
            "ArchiveConflictPanel"
        )

        if !hasStoredFrame() {

            newPanel.center()
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

    // MARK: - Stored Frame Check

    private func hasStoredFrame() -> Bool {

        let key =
            "NSWindow Frame ArchiveConflictPanel"

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
