import SwiftUI

struct ArchiveConflictView: View {

    let conflict:
        ArchiveConflict

    let onUseSuggestedFilename:
        () -> Void

    let onChangeFilename:
        () -> Void

    let onCancel:
        () -> Void

    var body: some View {

        VStack(
            spacing:
                0
        ) {

            header

            Divider()

            comparison

            Divider()

            footer
        }
        .frame(
            minWidth:
                980,
            minHeight:
                680
        )
    }

    // MARK: - Header

    private var header:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {

            HStack(
                alignment:
                    .top,
                spacing:
                    12
            ) {

                Image(
                    systemName:
                        conflict.isIdentical
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .font(
                    .title2
                )

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        6
                ) {

                    Text(
                        conflict.isIdentical
                        ? "Dokument bereits vorhanden"
                        : "Dateiname bereits vorhanden"
                    )
                    .font(
                        .headline
                    )

                    Text(
                        conflict.isIdentical
                        ? "Die vorhandene Archivdatei ist inhaltlich identisch mit dem neuen Dokument."
                        : "Im Zielordner existiert bereits eine Datei mit demselben Namen, der Inhalt ist jedoch unterschiedlich."
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()
            }

            if !conflict.isIdentical {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        4
                ) {

                    Text(
                        "Vorgeschlagener neuer Dateiname"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        conflict.suggestedFilename
                    )
                    .font(
                        .body
                            .monospaced()
                    )
                    .textSelection(
                        .enabled
                    )
                }
            }
        }
        .padding(
            20
        )
    }

    // MARK: - Comparison

    private var comparison:
        some View {

        HSplitView {

            pdfColumn(
                title:
                    "Zu archivierende Datei",
                url:
                    conflict.sourceURL
            )

            pdfColumn(
                title:
                    "Bereits im Archiv vorhanden",
                url:
                    conflict.existingURL
            )
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }

    // MARK: - PDF Column

    private func pdfColumn(
        title: String,
        url: URL
    ) -> some View {

        VStack(
            spacing:
                0
        ) {

            HStack {

                Text(
                    title
                )
                .font(
                    .headline
                )

                Spacer()

                Text(
                    url.lastPathComponent
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(
                    1
                )
                .truncationMode(
                    .middle
                )
            }
            .padding(
                12
            )

            Divider()

            PDFPreviewView(
                url:
                    url
            )
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
        }
        .frame(
            minWidth:
                420
        )
    }

    // MARK: - Footer

    private var footer:
        some View {

        HStack(
            spacing:
                12
        ) {

            Button(
                "Abbrechen"
            ) {

                onCancel()
            }

            if !conflict.isIdentical {

                Button(
                    "Dateiname ändern"
                ) {

                    onChangeFilename()
                }
            }

            Spacer()

            if conflict.isIdentical {

                Button(
                    "Duplikat aus Eingang entfernen"
                ) {

                    onUseSuggestedFilename()
                }
                .buttonStyle(
                    .borderedProminent
                )

            } else {

                Button(
                    "Als \(conflict.suggestedFilename) archivieren"
                ) {

                    onUseSuggestedFilename()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(
            16
        )
    }
}
