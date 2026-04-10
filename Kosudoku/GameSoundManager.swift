//
//  GameSoundManager.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/22/26.
//

import AVFoundation

/// Manages gameplay sound effects using synthesized tones
final class GameSoundManager {
    static let shared = GameSoundManager()
    
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let sampleRate: Double = 44100
    private var isSetUp = false
    
    private init() {
        setUp()
    }
    
    private func setUp() {
        let eng = AVAudioEngine()
        let node = AVAudioPlayerNode()
        eng.attach(node)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        eng.connect(node, to: eng.mainMixerNode, format: format)
        engine = eng
        playerNode = node
        isSetUp = true
    }
    
    /// Play a brief pleasant chime for a correct guess
    func playCorrectSound(pack: SoundPack = .classic) {
        guard isSetUp else { return }
        let buffer: AVAudioPCMBuffer?
        switch pack {
        case .classic: buffer = generateChimeBuffer()
        case .retro: buffer = generateRetroChimeBuffer()
        case .zen: buffer = generateZenChimeBuffer()
        case .arcade: buffer = generateArcadeChimeBuffer()
        }
        guard let buffer else { return }
        playBuffer(buffer)
    }
    
    /// Play a short buzzer sound for an incorrect guess
    func playIncorrectSound(pack: SoundPack = .classic) {
        guard isSetUp else { return }
        let buffer: AVAudioPCMBuffer?
        switch pack {
        case .classic: buffer = generateBuzzerBuffer()
        case .retro: buffer = generateRetroBuzzerBuffer()
        case .zen: buffer = generateZenBuzzerBuffer()
        case .arcade: buffer = generateArcadeBuzzerBuffer()
        }
        guard let buffer else { return }
        playBuffer(buffer)
    }
    
    /// Play a celebratory sound (applause + whistle) for winning
    func playWinSound(pack: SoundPack = .classic) {
        guard isSetUp else { return }
        let buffer: AVAudioPCMBuffer?
        switch pack {
        case .classic: buffer = generateWinBuffer()
        case .retro: buffer = generateRetroWinBuffer()
        case .zen: buffer = generateZenWinBuffer()
        case .arcade: buffer = generateArcadeWinBuffer()
        }
        guard let buffer else { return }
        playBuffer(buffer)
    }
    
    /// Play a crowd laughing sound for losing
    func playLoseSound(pack: SoundPack = .classic) {
        guard isSetUp else { return }
        let buffer: AVAudioPCMBuffer?
        switch pack {
        case .classic: buffer = generateLoseBuffer()
        case .retro: buffer = generateRetroLoseBuffer()
        case .zen: buffer = generateZenLoseBuffer()
        case .arcade: buffer = generateArcadeLoseBuffer()
        }
        guard let buffer else { return }
        playBuffer(buffer)
    }
    
    /// Play a short click sound for notifications
    func playNotificationSound() {
        guard isSetUp, let buffer = generateNotificationClickBuffer() else { return }
        playBuffer(buffer)
    }
    
    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let engine, let playerNode else { return }
        do {
            if !engine.isRunning {
                try engine.start()
            }
            playerNode.stop()
            playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self?.playerNode?.isPlaying == false {
                        self?.engine?.pause()
                    }
                }
            }
            playerNode.play()
        } catch {
            print("Sound playback error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Tone Generation
    
    /// Generates a bright two-tone chime (C6 → E6) with a quick fade-out
    private func generateChimeBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.25
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let freq1: Double = 1047  // C6
        let freq2: Double = 1319  // E6
        let halfFrames = Int(frameCount / 2)
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Envelope: quick attack, smooth decay
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress * progress) * 0.4)
            
            if i < halfFrames {
                // First half: C6
                data[i] = Float(sin(2.0 * .pi * freq1 * t)) * envelope
            } else {
                // Second half: E6
                data[i] = Float(sin(2.0 * .pi * freq2 * t)) * envelope
            }
        }
        
        return buffer
    }
    
    /// Generates applause (noise bursts) layered with a rising whistle
    private func generateWinBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 2.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration
            
            // Applause: rapid random bursts shaped by an envelope
            let clapEnvelope = Float(sin(Double.pi * progress) * 0.3)
            // Rapid amplitude modulation simulates individual "claps"
            let clapMod = Float(abs(sin(t * 40.0 * Double.pi))) // ~20 claps/sec
            let noise = Float.random(in: -1...1) * clapEnvelope * clapMod
            
            // Whistle: sine that sweeps from ~1200 Hz to ~2400 Hz
            let whistleFreq = 1200.0 + 1200.0 * progress
            let whistleEnv: Float
            if progress < 0.1 {
                whistleEnv = Float(progress / 0.1) * 0.25 // fade in
            } else if progress > 0.7 {
                whistleEnv = Float((1.0 - progress) / 0.3) * 0.25 // fade out
            } else {
                whistleEnv = 0.25
            }
            // Add slight vibrato for realism
            let vibrato = sin(t * 6.0 * Double.pi) * 30.0
            let whistle = Float(sin(2.0 * Double.pi * (whistleFreq + vibrato) * t)) * whistleEnv
            
            data[i] = noise + whistle
        }
        
        return buffer
    }
    
    /// Generates a rhythmic "ha-ha-ha" laughing sound
    private func generateLoseBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 1.8
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        // Laugh rhythm: ~5 "ha" bursts per second
        let laughRate = 5.0
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration
            
            // Overall envelope: fade in then out
            let overallEnv: Float
            if progress < 0.05 {
                overallEnv = Float(progress / 0.05)
            } else if progress > 0.75 {
                overallEnv = Float((1.0 - progress) / 0.25)
            } else {
                overallEnv = 1.0
            }
            
            // Rhythmic bursts — each "ha" is a quick ramp up/down
            let laughPhase = t * laughRate
            let burstPhase = laughPhase - floor(laughPhase) // 0..1 within each burst
            let burstEnv: Float
            if burstPhase < 0.15 {
                burstEnv = Float(burstPhase / 0.15)
            } else if burstPhase < 0.5 {
                burstEnv = Float(1.0 - (burstPhase - 0.15) / 0.35)
            } else {
                burstEnv = 0
            }
            
            // Voice-like tone: fundamental ~250 Hz with harmonics
            let fundamental = 250.0 + 20.0 * sin(t * 3.0 * Double.pi) // slight pitch wobble
            let h1 = Float(sin(2.0 * Double.pi * fundamental * t))
            let h2 = Float(sin(2.0 * Double.pi * fundamental * 2.0 * t)) * 0.5
            let h3 = Float(sin(2.0 * Double.pi * fundamental * 3.0 * t)) * 0.3
            let voice = (h1 + h2 + h3) / 1.8
            
            // Add a small amount of noise for breathiness
            let breath = Float.random(in: -1...1) * 0.1
            
            data[i] = (voice + breath) * burstEnv * overallEnv * 0.4
        }
        
        return buffer
    }
    
    /// Generates a short, soft click/pop for notification banners
    private func generateNotificationClickBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.08
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        // A quick "pop" — short sine burst at ~880 Hz with rapid decay
        let freq: Double = 880
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            // Fast exponential decay
            let envelope = Float(exp(-progress * 8.0) * 0.35)
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
        }
        
        return buffer
    }
    
    /// Play a shimmering shield activation sound
    func playShieldSound() {
        guard isSetUp, let buffer = generateShieldBuffer() else { return }
        playBuffer(buffer)
    }
    
    /// Play a soft hint reveal sound
    func playHintSound() {
        guard isSetUp, let buffer = generateHintBuffer() else { return }
        playBuffer(buffer)
    }
    
    /// Generates a short abrupt buzzer (low frequency with slight noise)
    private func generateBuzzerBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.2
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let freq: Double = 150  // Low buzz frequency
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Sharp cutoff envelope for abrupt feel
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.5)
            
            // Square-ish wave (clipped sine) for harsh buzzer timbre
            let sine = sin(2.0 * .pi * freq * t)
            let clipped = max(-0.6, min(0.6, sine * 1.5))
            data[i] = Float(clipped) * envelope
        }
        
        return buffer
    }
    
    /// Generates a shimmering ascending tone for shield activation
    private func generateShieldBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.35
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.4)
            // Rising shimmer: two tones sweeping up
            let freq1 = 800.0 + 600.0 * progress
            let freq2 = 1200.0 + 800.0 * progress
            let tone = Float(sin(2.0 * .pi * freq1 * t)) * 0.6 + Float(sin(2.0 * .pi * freq2 * t)) * 0.4
            data[i] = tone * envelope
        }
        return buffer
    }
    
    /// Generates a crystalline descending tone for time freeze
    /// Play a sound effect for a specific emote
    func playEmoteSound(for emote: GameEmote) {
        guard isSetUp else { return }
        let buffer: AVAudioPCMBuffer?
        switch emote {
        case .gg:        buffer = generateGGBuffer()
        case .sweat:     buffer = generateSweatBuffer()
        case .fire:      buffer = generateFireBuffer()
        case .flex:      buffer = generateFlexBuffer()
        case .cool:      buffer = generateCoolBuffer()
        case .mindBlown: buffer = generateMindBlownBuffer()
        // Celebration Pack
        case .party:     buffer = generatePartyBuffer()
        case .heartEyes: buffer = generateHeartEyesBuffer()
        case .trophy:    buffer = generateTrophyBuffer()
        case .rocket:    buffer = generateRocketBuffer()
        case .sparkles:  buffer = generateSparklesBuffer()
        case .clown:     buffer = generateClownBuffer()
        // Animals Pack
        case .cat:       buffer = generateCatBuffer()
        case .dog:       buffer = generateDogBuffer()
        case .monkey:    buffer = generateMonkeyBuffer()
        case .penguin:   buffer = generatePenguinBuffer()
        case .unicorn:   buffer = generateUnicornBuffer()
        case .dragon:    buffer = generateDragonBuffer()
        }
        guard let buffer else { return }
        playBuffer(buffer)
    }
    
    // MARK: - Emote Sound Generation
    
    /// Quick double-tap percussion for 👏
    private func generateGGBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.35
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            // Two quick taps at t=0 and t=0.15
            let tap1 = t < 0.12 ? Float(exp(-t * 40.0) * 0.4) : Float(0)
            let tap2 = t > 0.15 && t < 0.27 ? Float(exp(-(t - 0.15) * 40.0) * 0.35) : Float(0)
            let freq1 = 1200.0 + 200.0 * progress
            let tone = Float(sin(2.0 * .pi * freq1 * t))
            data[i] = tone * (tap1 + tap2)
        }
        return buffer
    }
    
    /// Descending "whomp" slide for 😅
    private func generateSweatBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.4)
            // Descending frequency from 600 Hz to 150 Hz
            let freq = 600.0 - 450.0 * progress
            let tone = Float(sin(2.0 * .pi * freq * t))
            data[i] = tone * envelope
        }
        return buffer
    }
    
    /// Rising crackle/sizzle for 🔥
    private func generateFireBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.45
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.35)
            // Rising tone with noise for crackle
            let freq = 400.0 + 800.0 * progress
            let tone = Float(sin(2.0 * .pi * freq * t)) * 0.6
            let noise = Float.random(in: -1...1) * 0.4 * Float(progress)
            data[i] = (tone + noise) * envelope
        }
        return buffer
    }
    
    /// Punchy bass hit for 💪
    private func generateFlexBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            // Fast attack, medium decay
            let envelope = Float(exp(-progress * 6.0) * 0.5)
            // Low bass with a punchy transient
            let bass = Float(sin(2.0 * .pi * 80.0 * t))
            let transient = Float(sin(2.0 * .pi * 400.0 * t)) * Float(exp(-progress * 20.0))
            data[i] = (bass * 0.7 + transient * 0.3) * envelope
        }
        return buffer
    }
    
    /// Smooth two-note riff for 😎
    private func generateCoolBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let halfFrames = Int(frameCount / 2)
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.35)
            // E4 → G4 (jazzy minor third)
            let freq = i < halfFrames ? 330.0 : 392.0
            let tone = Float(sin(2.0 * .pi * freq * t))
            let harmonic = Float(sin(2.0 * .pi * freq * 2.0 * t)) * 0.3
            data[i] = (tone + harmonic) * envelope
        }
        return buffer
    }
    
    /// Ascending sweep ending in sparkle burst for 🤯
    private func generateMindBlownBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.4)
            // Ascending sweep from 300 Hz to 2000 Hz
            let freq = 300.0 + 1700.0 * progress * progress
            let sweep = Float(sin(2.0 * .pi * freq * t))
            // Add sparkle in the last 30%
            let sparkle: Float
            if progress > 0.7 {
                let sparkleProgress = (progress - 0.7) / 0.3
                sparkle = Float(sin(2.0 * .pi * 3000.0 * t)) * Float(sparkleProgress) * 0.4
            } else {
                sparkle = 0
            }
            data[i] = (sweep + sparkle) * envelope
        }
        return buffer
    }
    
    // MARK: - Retro Sound Pack (8-bit style)
    
    private func generateRetroChimeBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.25
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.4)
            // Square wave for 8-bit feel
            let freq = i < Int(frameCount / 2) ? 523.0 : 659.0
            let wave = sin(2.0 * .pi * freq * t) > 0 ? Float(1.0) : Float(-1.0)
            data[i] = wave * envelope
        }
        return buffer
    }
    
    private func generateRetroBuzzerBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.2
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.4)
            let freq = 100.0 + 50.0 * sin(t * 30.0 * .pi)
            let wave = sin(2.0 * .pi * freq * t) > 0 ? Float(1.0) : Float(-1.0)
            data[i] = wave * envelope
        }
        return buffer
    }
    
    private func generateRetroWinBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 1.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let notes: [(freq: Double, start: Double, dur: Double)] = [
            (523, 0.0, 0.2), (659, 0.2, 0.2), (784, 0.4, 0.2),
            (1047, 0.6, 0.4), (784, 1.0, 0.2), (1047, 1.2, 0.3)
        ]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample: Float = 0
            for note in notes {
                if t >= note.start && t < note.start + note.dur {
                    let noteProgress = (t - note.start) / note.dur
                    let env = Float(max(0, 1.0 - noteProgress) * 0.35)
                    let wave = sin(2.0 * .pi * note.freq * t) > 0 ? Float(1.0) : Float(-1.0)
                    sample += wave * env
                }
            }
            data[i] = sample
        }
        return buffer
    }
    
    private func generateRetroLoseBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 1.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.35)
            let freq = 400.0 - 300.0 * progress
            let wave = sin(2.0 * .pi * freq * t) > 0 ? Float(1.0) : Float(-1.0)
            data[i] = wave * envelope
        }
        return buffer
    }
    
    // MARK: - Zen Sound Pack (soft tones)
    
    private func generateZenChimeBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.25)
            let tone1 = Float(sin(2.0 * .pi * 528.0 * t)) * 0.6
            let tone2 = Float(sin(2.0 * .pi * 396.0 * t)) * 0.4
            data[i] = (tone1 + tone2) * envelope
        }
        return buffer
    }
    
    private func generateZenBuzzerBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.2)
            let freq = 220.0 - 80.0 * progress
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
        }
        return buffer
    }
    
    private func generateZenWinBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 2.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let envelope = Float(sin(Double.pi * progress) * 0.25)
            let f1 = 264.0 + 132.0 * sin(progress * .pi)
            let f2 = 396.0 + 66.0 * sin(progress * .pi * 2)
            let tone = Float(sin(2.0 * .pi * f1 * t)) * 0.5 + Float(sin(2.0 * .pi * f2 * t)) * 0.5
            data[i] = tone * envelope
        }
        return buffer
    }
    
    private func generateZenLoseBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 1.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration
            let envelope = Float(sin(Double.pi * progress) * 0.2)
            let freq = 330.0 - 110.0 * progress
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
        }
        return buffer
    }
    
    // MARK: - Arcade Sound Pack (coin/power-up style)
    
    private func generateArcadeChimeBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.2
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(exp(-progress * 5.0) * 0.4)
            let freq = 800.0 + 1200.0 * progress
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
        }
        return buffer
    }
    
    private func generateArcadeBuzzerBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.15
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.45)
            let freq = 200.0 - 100.0 * progress
            let wave = Float(sin(2.0 * .pi * freq * t))
            let noise = Float.random(in: -0.3...0.3)
            data[i] = (wave + noise) * envelope
        }
        return buffer
    }
    
    private func generateArcadeWinBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 1.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let notes: [(freq: Double, start: Double, dur: Double)] = [
            (880, 0.0, 0.15), (1047, 0.15, 0.15), (1319, 0.3, 0.15),
            (1568, 0.45, 0.15), (1760, 0.6, 0.3), (2093, 0.9, 0.5)
        ]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample: Float = 0
            for note in notes {
                if t >= note.start && t < note.start + note.dur {
                    let noteProgress = (t - note.start) / note.dur
                    let env = Float(exp(-noteProgress * 3.0) * 0.35)
                    sample += Float(sin(2.0 * .pi * note.freq * t)) * env
                }
            }
            data[i] = sample
        }
        return buffer
    }
    
    private func generateArcadeLoseBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.8
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress) * 0.4)
            let freq = 600.0 - 400.0 * progress
            let tone = Float(sin(2.0 * .pi * freq * t))
            let harm = Float(sin(2.0 * .pi * freq * 0.5 * t)) * 0.3
            data[i] = (tone + harm) * envelope
        }
        return buffer
    }
    
    // MARK: - Celebration Pack Emote Sounds
    
    /// Rising sparkle burst for 🎉
    private func generatePartyBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.35)
            let freq = 600.0 + 1400.0 * progress
            let tone = Float(sin(2.0 * .pi * freq * t))
            let sparkle = Float(sin(2.0 * .pi * 2500.0 * t)) * Float(progress) * 0.3
            data[i] = (tone + sparkle) * envelope
        }
        return buffer
    }
    
    /// Soft ascending two-note for 😍
    private func generateHeartEyesBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let halfFrames = Int(frameCount / 2)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.3)
            let freq = i < halfFrames ? 440.0 : 554.0
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
        }
        return buffer
    }
    
    /// Fanfare blast for 🏆
    private func generateTrophyBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.6
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let notes: [(freq: Double, start: Double, dur: Double)] = [
            (523, 0.0, 0.15), (659, 0.15, 0.15), (784, 0.3, 0.3)
        ]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample: Float = 0
            for note in notes {
                if t >= note.start && t < note.start + note.dur {
                    let np = (t - note.start) / note.dur
                    let env = Float(max(0, 1.0 - np * np) * 0.35)
                    sample += Float(sin(2.0 * .pi * note.freq * t)) * env
                    sample += Float(sin(2.0 * .pi * note.freq * 2.0 * t)) * env * 0.3
                }
            }
            data[i] = sample
        }
        return buffer
    }
    
    /// Rising whoosh for 🚀
    private func generateRocketBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.35)
            let freq = 200.0 + 2000.0 * progress * progress
            let noise = Float.random(in: -1...1) * 0.2 * Float(1.0 - progress)
            data[i] = (Float(sin(2.0 * .pi * freq * t)) + noise) * envelope
        }
        return buffer
    }
    
    /// Twinkling chime for ✨
    private func generateSparklesBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.3)
            let f1 = 2000.0 + 500.0 * sin(t * 20.0 * .pi)
            let f2 = 3000.0 + 300.0 * sin(t * 15.0 * .pi)
            data[i] = (Float(sin(2.0 * .pi * f1 * t)) * 0.5 + Float(sin(2.0 * .pi * f2 * t)) * 0.5) * envelope
        }
        return buffer
    }
    
    /// Honk for 🤡
    private func generateClownBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(exp(-progress * 4.0) * 0.4)
            let wave = sin(2.0 * .pi * 180.0 * t) > 0 ? Float(1.0) : Float(-1.0)
            data[i] = wave * envelope
        }
        return buffer
    }
    
    // MARK: - Animals Pack Emote Sounds
    
    /// High-pitched meow sweep for 🐱
    private func generateCatBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.35)
            let freq = 800.0 + 400.0 * sin(progress * .pi)
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
        }
        return buffer
    }
    
    /// Short bark (noise burst) for 🐶
    private func generateDogBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.2
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(exp(-progress * 8.0) * 0.4)
            let tone = Float(sin(2.0 * .pi * 350.0 * t))
            let noise = Float.random(in: -1...1) * 0.3
            data[i] = (tone + noise) * envelope
        }
        return buffer
    }
    
    /// Chittering for 🙈
    private func generateMonkeyBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.3)
            let fm = sin(t * 80.0 * .pi) * 300.0
            let freq = 700.0 + fm
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
        }
        return buffer
    }
    
    /// Short waddle honk for 🐧
    private func generatePenguinBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.25
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(exp(-progress * 5.0) * 0.35)
            let freq = 500.0 + 200.0 * sin(progress * .pi * 2)
            data[i] = Float(sin(2.0 * .pi * freq * t)) * envelope
        }
        return buffer
    }
    
    /// Magical ascending arpeggio for 🦄
    private func generateUnicornBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.6
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let notes: [(freq: Double, start: Double, dur: Double)] = [
            (523, 0.0, 0.15), (659, 0.12, 0.15), (784, 0.24, 0.15), (1047, 0.36, 0.24)
        ]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample: Float = 0
            for note in notes {
                if t >= note.start && t < note.start + note.dur {
                    let np = (t - note.start) / note.dur
                    let env = Float(sin(Double.pi * np) * 0.3)
                    sample += Float(sin(2.0 * .pi * note.freq * t)) * env
                }
            }
            data[i] = sample
        }
        return buffer
    }
    
    /// Low growl for 🐉
    private func generateDragonBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(sin(Double.pi * progress) * 0.4)
            let bass = Float(sin(2.0 * .pi * 60.0 * t))
            let noise = Float.random(in: -1...1) * 0.3
            let growl = Float(sin(2.0 * .pi * 120.0 * t)) * Float(abs(sin(t * 20.0 * .pi)))
            data[i] = (bass * 0.4 + noise * 0.3 + growl * 0.3) * envelope
        }
        return buffer
    }
    
    /// Generates a gentle ascending chime for hint reveal
    private func generateHintBuffer() -> AVAudioPCMBuffer? {
        let duration: Double = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let freq1: Double = 880   // A5
        let freq2: Double = 1320  // E6
        let thirdFrames = Int(frameCount / 3)
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = Float(max(0, 1.0 - progress * progress) * 0.35)
            if i < thirdFrames {
                data[i] = Float(sin(2.0 * .pi * freq1 * t)) * envelope
            } else {
                data[i] = Float(sin(2.0 * .pi * freq2 * t)) * envelope
            }
        }
        return buffer
    }
}
