import Foundation

public enum Instrument: UInt32, CustomStringConvertible, CaseIterable, Identifiable {
  public var id: Int { Int(rawValue) }
  
  case none,
       drums,
       djembe,
       electricGuitar,
       acousticGuitar,
       bassGuitar,
       keyboard,
       synth,
       grandPiano,
       accordian,
       vocals,
       microphone,
       harmonica,
       trumpet,
       trombone,
       frenchHorn,
       tuba,
       sax,
       clarinet,
       flute,
       violin,
       cello,
       doubleBass,
       recorder,
       streamer,
       listener,
       guitarAndVocals,
       keyboardAndVocals,
       bodhran,
       bassoon,
       oboe,
       harp,
       viola,
       congas,
       bongo,
       bassVocals,
       tenorVocals,
       altoVocals,
       sopranoVocals,
       banjo,
       mandolin,
       ukelele,
       bassUkelele,
       baritoneVocals,
       leadVocals
  
  public var name: String {
    switch self {
    case .drums: return "Drums"
      
    case .none: return "None"
    case .djembe: return "Djembe"
    case .electricGuitar: return "Electric Guitar"
    case .acousticGuitar: return "Acoustic Guitar"
    case .bassGuitar: return "Bass Guitar"
    case .keyboard: return "Keyboard"
    case .synth: return "Synth"
    case .grandPiano: return "Grand Piano"
    case .accordian: return "Accordian"
    case .vocals: return "Vocals"
    case .microphone: return "Mic"
    case .harmonica: return "Harmonica"
    case .trumpet: return "Trumpet"
    case .trombone: return "Trombone"
    case .frenchHorn: return "French Horn"
    case .tuba: return "Tuba"
    case .sax: return "Saxophone"
    case .clarinet: return "Clarinet"
    case .flute: return "Flute"
    case .violin: return "Violin"
    case .cello: return "Cello"
    case .doubleBass: return "Double Bass"
    case .recorder: return "Recorder"
    case .streamer: return "Streamer"
    case .listener: return "Listener"
    case .guitarAndVocals: return "Guitar / Vocals"
    case .keyboardAndVocals: return "Keyboard / Vocals"
    case .bodhran: return "Bodhran"
    case .bassoon: return "Bassoon"
    case .oboe: return "Oboe"
    case .harp: return "Harp"
    case .viola: return "Viola"
    case .congas: return "Congas"
    case .bongo: return "Bongo"
    case .bassVocals: return "Vocals (Bass)"
    case .tenorVocals: return "Vocals (Tenor)"
    case .altoVocals: return "Vocals (Alto)"
    case .sopranoVocals: return "Vocals (Soprano)"
    case .banjo: return "Banjo"
    case .mandolin: return "Mandolin"
    case .ukelele: return "Ukelele"
    case .bassUkelele: return "Bass Ukelele"
    case .baritoneVocals: return "Vocals (Baritone)"
    case .leadVocals: return "Lead Vocals"
    }
  }
  
  public var description: String {
    name
  }
  
  public var icon: String {
    switch self {
    case .drums: return "🥁"
    case .djembe: return "🪘"
    case .electricGuitar: return "🎸"
    case .acousticGuitar: return "🎸"
    case .bassGuitar: return "🎸"
    case .keyboard: return "🎹"
    case .synth: return "🎹"
    case .grandPiano: return "🎹"
    case .accordian: return "🪗"
    case .microphone: return "🎤"
    case .trumpet: return "🎺"
    case .sax: return "🎷"
    case .violin: return "🎻"
    case .cello: return "🎻"
    case .doubleBass: return "🎻"
    case .recorder: return "⏺"
    case .streamer: return "🔊"
    case .listener: return "🎧"
    case .guitarAndVocals: return "🎸🎙"
    case .keyboardAndVocals: return "🎹🎙"
    case .viola: return "🎻"
    case .congas: return "🪘"
    case .bongo: return "🪘"
    case .banjo: return "🪕"
      
    case .vocals,
         .baritoneVocals,
         .bassVocals,
         .tenorVocals,
         .altoVocals,
         .sopranoVocals,
         .leadVocals: return "🎙"
      
    default: return ""
    }
  }
}
