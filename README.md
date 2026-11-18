# Fretty

A native SwiftUI iOS app for learning the guitar fretboard: note names, reading the treble staff, and chord shapes.

## Features

- **Play**: quizzes for Notes (find it / name it), Staff (name it / play it) and Chords (build it / name it), with fret-zone, string and naturals-only filters. Run them endless, as a fixed number of questions, or timed.
- **Spaced repetition**: every fret, staff pitch and chord voicing is tracked in Leitner boxes. Due items and weak spots come up first, and missed questions come back a few turns later.
- **Feedback**: explanations for wrong answers (for example "Same pitch as the open G string"), combo streaks, personal bests, day streaks, haptics and a plucked-string synth.
- **Progress**: your toughest notes, staff positions and chords, plus accuracy heat bars.
- **Learn**: an interactive fretboard explorer for notes, the staff and every chord voicing, with strum playback.

## Building

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
open Fretty.xcodeproj
```

Fonts: Figtree, DM Mono and Noto Music (SIL Open Font License), bundled in `Fretty/Resources/Fonts`.
