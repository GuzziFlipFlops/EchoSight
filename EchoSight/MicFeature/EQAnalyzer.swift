import Accelerate
import AVFoundation
import Foundation

final class EQAnalyzer {
    private let fftSize: Int = 1024
    private let smoothing: Float = 0.25
    private let bandEdges: [Float] = [80, 250, 700, 2000, 6000, 12000]

    private var fftSetup: FFTSetup?
    private var window: [Float]
    private var windowed: [Float]
    private var real: [Float]
    private var imag: [Float]
    private var mags: [Float]
    private var smoothedBands: [Float] = Array(repeating: 0, count: 5)

    init() {
        let log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        window = Array(repeating: 0, count: fftSize)
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
        guard let fftSetup else { return smoothedBands }
        guard let channel = buffer.floatChannelData?.pointee else { return smoothedBands }
        let n = Int(buffer.frameLength)
        guard n >= fftSize else { return smoothedBands }

        windowed.withUnsafeMutableBufferPointer { wOut in
            window.withUnsafeBufferPointer { win in
                vDSP_vmul(channel, 1, win.baseAddress!, 1, wOut.baseAddress!, 1, vDSP_Length(fftSize))
            }
        }

        var split = DSPSplitComplex(realp: &real, imagp: &imag)
        windowed.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(fftSize / 2))
            }
        }

        let log2n = vDSP_Length(log2(Float(fftSize)))
        vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

        mags.withUnsafeMutableBufferPointer { mPtr in
            vDSP_zvmags(&split, 1, mPtr.baseAddress!, 1, vDSP_Length(fftSize / 2))
        }

        let newBands = computeBands(from: mags, sampleRate: sampleRate)
        for i in 0..<5 {
            smoothedBands[i] = (1 - smoothing) * smoothedBands[i] + smoothing * newBands[i]
        }
        return smoothedBands
    }

    private func computeBands(from mags: [Float], sampleRate: Float) -> [Float] {
        let binHz = sampleRate / Float(fftSize)
        var bandVals = Array(repeating: Float(0), count: 5)

        for b in 0..<5 {
            let f0 = bandEdges[b]
            let f1 = bandEdges[b + 1]
            let i0 = max(1, Int(f0 / binHz))
            let i1 = min(mags.count - 1, Int(f1 / binHz))
            if i1 <= i0 { continue }

            var sum: Float = 0
            for i in i0..<i1 { sum += mags[i] }
            let compressed = log10(1 + sum)
            let normalized = min(compressed / 4.5, 1)
            bandVals[b] = normalized
        }

        return bandVals
    }
}
