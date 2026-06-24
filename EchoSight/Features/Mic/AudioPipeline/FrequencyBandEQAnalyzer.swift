// MARK: - File Guide
// Turns microphone samples into five readable frequency bands using FFT.
// The UI uses these bands for smooth visual meters.

import Accelerate
import AVFoundation
import Foundation

// Converts raw microphone audio into five smoothed frequency bands.
// It uses Accelerate/vDSP FFT for performance, then compresses values so the UI
// bars move smoothly instead of jumping around.
final class EQAnalyzer {
    // 1024 samples gives a responsive, lightweight FFT for live UI.
    private let fftSize: Int = 1024
    // Smoothing blends old and new values so bars do not jitter.
    private let smoothing: Float = 0.25
    // Frequency bucket edges: low, low-mid, mid, high-mid, high.
    private let bandEdges: [Float] = [80, 250, 700, 2000, 6000, 12000]

    // Reusable FFT memory.
    private var fftSetup: FFTSetup?
    private var window: [Float]
    private var windowed: [Float]
    private var real: [Float]
    private var imag: [Float]
    private var mags: [Float]
    private var smoothedBands: [Float] = Array(repeating: 0, count: 5)

    init() {
        // Preallocate all buffers once so processing is fast during live audio.
        let log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        window = Array(repeating: 0, count: fftSize)
        // Hann window reduces edge artifacts before FFT.
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        windowed = Array(repeating: 0, count: fftSize)
        real = Array(repeating: 0, count: fftSize / 2)
        imag = Array(repeating: 0, count: fftSize / 2)
        mags = Array(repeating: 0, count: fftSize / 2)
    }

    deinit {
        if let fftSetup { vDSP_destroy_fftsetup(fftSetup) }
    }

    func process(buffer: AVAudioPCMBuffer, sampleRate: Float) -> [Float] {
        // If anything is unavailable, keep returning the last good bands.
        guard let fftSetup else { return smoothedBands }
        guard let channel = buffer.floatChannelData?.pointee else { return smoothedBands }
        let sampleCount = Int(buffer.frameLength)
        guard sampleCount >= fftSize else { return smoothedBands }

        // Apply window to the first fftSize samples.
        windowed.withUnsafeMutableBufferPointer { wOut in
            window.withUnsafeBufferPointer { win in
                vDSP_vmul(channel, 1, win.baseAddress!, 1, wOut.baseAddress!, 1, vDSP_Length(fftSize))
            }
        }

        real.withUnsafeMutableBufferPointer { realBuffer in
            imag.withUnsafeMutableBufferPointer { imaginaryBuffer in
                // Convert real samples into split-complex form for vDSP FFT.
                var splitComplex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imaginaryBuffer.baseAddress!)
                windowed.withUnsafeBufferPointer { windowedSamples in
                    windowedSamples.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexSamples in
                        vDSP_ctoz(complexSamples, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                }

                let log2n = vDSP_Length(log2(Float(fftSize)))
                // Forward FFT converts waveform into frequency spectrum.
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Magnitude squared gives energy at each frequency bin.
                mags.withUnsafeMutableBufferPointer { magnitudeBuffer in
                    vDSP_zvmags(&splitComplex, 1, magnitudeBuffer.baseAddress!, 1, vDSP_Length(fftSize / 2))
                }
            }
        }

        let newBands = computeBands(from: mags, sampleRate: sampleRate)
        for bandIndex in 0..<5 {
            // Exponential moving average smooths visual movement.
            smoothedBands[bandIndex] = (1 - smoothing) * smoothedBands[bandIndex] + smoothing * newBands[bandIndex]
        }
        return smoothedBands
    }

    private func computeBands(from mags: [Float], sampleRate: Float) -> [Float] {
        // binHz tells how many Hz each FFT bin represents.
        let binHz = sampleRate / Float(fftSize)
        var bandValues = Array(repeating: Float(0), count: 5)

        for bandIndex in 0..<5 {
            let lowerFrequency = bandEdges[bandIndex]
            let upperFrequency = bandEdges[bandIndex + 1]
            // Convert frequency edges into bin indexes.
            let lowerBinIndex = max(1, Int(lowerFrequency / binHz))
            let upperBinIndex = min(mags.count - 1, Int(upperFrequency / binHz))
            if upperBinIndex <= lowerBinIndex { continue }

            var magnitudeSum: Float = 0
            // Sum energy inside this frequency band.
            for binIndex in lowerBinIndex..<upperBinIndex {
                magnitudeSum += mags[binIndex]
            }
            // Log compression keeps values useful for both quiet and loud audio.
            let compressed = log10(1 + magnitudeSum)
            let normalized = min(compressed / 4.5, 1)
            bandValues[bandIndex] = normalized
        }

        return bandValues
    }
}
