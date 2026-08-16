import Foundation
import AppKit
import CoreImage

// MARK: - Field Image Processor

struct FieldImageProcessor {

    private let context =
        CIContext()

    // MARK: - Variants

    /// Erzeugt mehrere Bildvarianten eines
    /// kleinen Formularfeldes.
    ///
    /// Dadurch kann Vision später versuchen,
    /// schwache Handschrift unter verschiedenen
    /// Bedingungen zu erkennen.
    func variants(
        from image: NSImage
    ) -> [NSImage] {

        var result:
            [NSImage] = []

        // 1. Original
        result.append(
            image
        )

        // 2. Vergrößert
        if let enlarged =
            resize(
                image,
                scale: 2.0
            ) {

            result.append(
                enlarged
            )
        }

        // 3. Graustufen + Kontrast
        if let contrast =
            grayscaleContrast(
                image
            ) {

            result.append(
                contrast
            )

            // 4. Kontrastbild zusätzlich vergrößert
            if let enlargedContrast =
                resize(
                    contrast,
                    scale: 2.0
                ) {

                result.append(
                    enlargedContrast
                )
            }
        }

        // 5. Schwarz-Weiß
        if let blackAndWhite =
            blackAndWhite(
                image
            ) {

            result.append(
                blackAndWhite
            )
        }

        return result
    }

    // MARK: - Resize

    private func resize(
        _ image: NSImage,
        scale: CGFloat
    ) -> NSImage? {

        guard
            scale > 0
        else {

            return nil
        }

        let newSize =
            NSSize(
                width:
                    image.size.width
                    *
                    scale,
                height:
                    image.size.height
                    *
                    scale
            )

        let newImage =
            NSImage(
                size:
                    newSize
            )

        newImage.lockFocus()

        image.draw(
            in:
                NSRect(
                    origin:
                        .zero,
                    size:
                        newSize
                ),
            from:
                NSRect(
                    origin:
                        .zero,
                    size:
                        image.size
                ),
            operation:
                .copy,
            fraction:
                1.0
        )

        newImage.unlockFocus()

        return newImage
    }

    // MARK: - Grayscale + Contrast

    private func grayscaleContrast(
        _ image: NSImage
    ) -> NSImage? {

        guard
            let input =
                ciImage(
                    from:
                        image
                )
        else {

            return nil
        }

        guard
            let filter =
                CIFilter(
                    name:
                        "CIColorControls"
                )
        else {

            return nil
        }

        filter.setValue(
            input,
            forKey:
                kCIInputImageKey
        )

        filter.setValue(
            0.0,
            forKey:
                kCIInputSaturationKey
        )

        filter.setValue(
            1.8,
            forKey:
                kCIInputContrastKey
        )

        filter.setValue(
            0.05,
            forKey:
                kCIInputBrightnessKey
        )

        guard
            let output =
                filter.outputImage
        else {

            return nil
        }

        return nsImage(
            from:
                output
        )
    }

    // MARK: - Black + White

    private func blackAndWhite(
        _ image: NSImage
    ) -> NSImage? {

        guard
            let input =
                ciImage(
                    from:
                        image
                )
        else {

            return nil
        }

        // Erst Graustufen erzeugen.
        guard
            let grayscaleFilter =
                CIFilter(
                    name:
                        "CIColorControls"
                )
        else {

            return nil
        }

        grayscaleFilter.setValue(
            input,
            forKey:
                kCIInputImageKey
        )

        grayscaleFilter.setValue(
            0.0,
            forKey:
                kCIInputSaturationKey
        )

        grayscaleFilter.setValue(
            2.0,
            forKey:
                kCIInputContrastKey
        )

        guard
            let grayscale =
                grayscaleFilter
                    .outputImage
        else {

            return nil
        }

        // Helle Bereiche weiter aufhellen
        // und dunkle Schrift hervorheben.
        guard
            let exposureFilter =
                CIFilter(
                    name:
                        "CIExposureAdjust"
                )
        else {

            return nil
        }

        exposureFilter.setValue(
            grayscale,
            forKey:
                kCIInputImageKey
        )

        exposureFilter.setValue(
            0.7,
            forKey:
                kCIInputEVKey
        )

        guard
            let output =
                exposureFilter
                    .outputImage
        else {

            return nil
        }

        return nsImage(
            from:
                output
        )
    }

    // MARK: - NSImage → CIImage

    private func ciImage(
        from image: NSImage
    ) -> CIImage? {

        guard
            let cgImage =
                image.cgImage(
                    forProposedRect:
                        nil,
                    context:
                        nil,
                    hints:
                        nil
                )
        else {

            return nil
        }

        return CIImage(
            cgImage:
                cgImage
        )
    }

    // MARK: - CIImage → NSImage

    private func nsImage(
        from image: CIImage
    ) -> NSImage? {

        let extent =
            image.extent.integral

        guard
            !extent.isEmpty,
            let cgImage =
                context.createCGImage(
                    image,
                    from:
                        extent
                )
        else {

            return nil
        }

        return NSImage(
            cgImage:
                cgImage,
            size:
                NSSize(
                    width:
                        extent.width,
                    height:
                        extent.height
                )
        )
    }
}
