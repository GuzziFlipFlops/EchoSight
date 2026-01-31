import Foundation

enum SoundEventType: String, CaseIterable {
    case knock
    case beep
    case alarm
    case siren
    case speech

    var displayName: String {
        switch self {
        case .knock: return "Knock"
        case .beep: return "Beep"
        case .alarm: return "Alarm"
        case .siren: return "Siren"
        case .speech: return "Speech"
        }
    }
}

struct SoundEvent: Identifiable {
    let id = UUID()
    let type: SoundEventType
    let confidence: Float
    let timestamp: Date
}

final class SoundEventService {
    struct Thresholds {
        var knock: Float = 0.28
        var beep: Float = 0.35
        var alarm: Float = 0.30
        var speech: Float = 0.25
    }

    private let cooldowns: [SoundEventType: TimeInterval] = [
        .knock: 6,
        .beep: 5,
        .alarm: 10,
        .siren: 10,
        .speech: 4
    ]

    private var lastEventTimes: [SoundEventType: Date] = [:]
    private var lastBands: [Float] = Array(repeating: 0, count: 5)
    private var energyHistory: [Float] = []
    private let historySize: Int = 24

    var noisyMode: Bool = false
    var thresholds = Thresholds()

    func process(bands: [Float], rms: Float, timestamp: Date) -> SoundEvent? {
        guard bands.count >= 5 else { return nil }
        let multiplier: Float = noisyMode ? 1.5 : 1.0

        let lowEnergy = bands[0] + bands[1]
        let midEnergy = bands[2] + bands[3]
        let highEnergy = bands[4]

        let lastLow = lastBands[0] + lastBands[1]
        let lastHigh = lastBands[4]

        let lowTransient = lowEnergy - lastLow
        let highTransient = highEnergy - lastHigh

        energyHistory.append(midEnergy)
        if energyHistory.count > historySize {
            energyHistory.removeFirst()
        }

        defer { lastBands = bands }

        if lowTransient > thresholds.knock * multiplier, lowEnergy > thresholds.knock * multiplier {
            return emit(type: .knock, confidence: min(1, lowTransient / (thresholds.knock * multiplier)), at: timestamp)
        }

        if highTransient > thresholds.beep * multiplier, highEnergy > thresholds.beep * multiplier {
            return emit(type: .beep, confidence: min(1, highTransient / (thresholds.beep * multiplier)), at: timestamp)
        }

        if let sirenEvent = detectSirenOrAlarm(energyHistory: energyHistory, threshold: thresholds.alarm * multiplier, at: timestamp) {
            return sirenEvent
        }

        if rms > thresholds.speech * multiplier {
            return emit(type: .speech, confidence: min(1, rms / (thresholds.speech * multiplier)), at: timestamp)
        }

        return nil
    }

    private func detectSirenOrAlarm(energyHistory: [Float], threshold: Float, at timestamp: Date) -> SoundEvent? {
        guard energyHistory.count >= historySize else { return nil }
        let avg = energyHistory.reduce(0, +) / Float(energyHistory.count)
        let maxVal = energyHistory.max() ?? 0
        let minVal = energyHistory.min() ?? 0
        let range = maxVal - minVal
        guard avg > threshold, range > 0.08 else { return nil }

        let peaks = countPeaks(values: energyHistory, above: avg + range * 0.2)
        if peaks >= 2 {
            return emit(type: .siren, confidence: min(1, range * 2.5), at: timestamp)
        }
        return emit(type: .alarm, confidence: min(1, avg / threshold), at: timestamp)
    }

    private func countPeaks(values: [Float], above: Float) -> Int {
        guard values.count > 2 else { return 0 }
        var peaks = 0
        for i in 1..<(values.count - 1) {
            let prev = values[i - 1]
            let current = values[i]
            let next = values[i + 1]
            if current > prev && current > next && current > above {
                peaks += 1
            }
        }
        return peaks
    }

    private func emit(type: SoundEventType, confidence: Float, at timestamp: Date) -> SoundEvent? {
        if let last = lastEventTimes[type], timestamp.timeIntervalSince(last) < (cooldowns[type] ?? 0) {
            return nil
        }
        lastEventTimes[type] = timestamp
        return SoundEvent(type: type, confidence: confidence, timestamp: timestamp)
    }
}
