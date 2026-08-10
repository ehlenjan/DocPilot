import Foundation
import Vision

struct VisualFeatureSignature: Codable, Hashable {

    let data: Data
    let elementCount: Int
    let elementTypeRawValue: UInt

    init(
        data: Data,
        elementCount: Int,
        elementTypeRawValue: UInt
    ) {
        self.data = data
        self.elementCount = elementCount
        self.elementTypeRawValue = elementTypeRawValue
    }

    init(
        observation: VNFeaturePrintObservation
    ) {
        self.data =
            observation.data

        self.elementCount =
            observation.elementCount

        self.elementTypeRawValue =
            UInt(
                observation.elementType.rawValue
            )
    }

    // MARK: - Similarity

    /// 1.0 = sehr ähnlich
    /// 0.0 = sehr unähnlich
    func similarity(
        to other: VisualFeatureSignature
    ) -> Double? {

        guard
            elementCount > 0,
            elementCount == other.elementCount
        else {
            return nil
        }

        guard
            let firstVector = vectorValues(),
            let secondVector = other.vectorValues(),
            firstVector.count == secondVector.count
        else {
            return nil
        }

        var dotProduct =
            0.0

        var firstLength =
            0.0

        var secondLength =
            0.0

        for index in
            firstVector.indices {

            let first =
                firstVector[index]

            let second =
                secondVector[index]

            dotProduct +=
                first * second

            firstLength +=
                first * first

            secondLength +=
                second * second
        }

        guard
            firstLength > 0,
            secondLength > 0
        else {
            return nil
        }

        let denominator =
            sqrt(firstLength) *
            sqrt(secondLength)

        guard denominator > 0
        else {
            return nil
        }

        let cosine =
            dotProduct /
            denominator

        return max(
            0,
            min(
                cosine,
                1
            )
        )
    }

    // MARK: - Vector

    private func vectorValues()
        -> [Double]? {

        guard
            elementCount > 0,
            !data.isEmpty
        else {
            return nil
        }

        let bytesPerElement =
            data.count /
            elementCount

        switch bytesPerElement {

        case MemoryLayout<Float>.size:

            return data.withUnsafeBytes {
                rawBuffer in

                let buffer =
                    rawBuffer.bindMemory(
                        to: Float.self
                    )

                guard
                    buffer.count >=
                        elementCount
                else {
                    return nil
                }

                return buffer
                    .prefix(
                        elementCount
                    )
                    .map {
                        Double($0)
                    }
            }

        case MemoryLayout<Double>.size:

            return data.withUnsafeBytes {
                rawBuffer in

                let buffer =
                    rawBuffer.bindMemory(
                        to: Double.self
                    )

                guard
                    buffer.count >=
                        elementCount
                else {
                    return nil
                }

                return Array(
                    buffer.prefix(
                        elementCount
                    )
                )
            }

        default:

            return nil
        }
    }
}
