import Foundation
import Testing
@testable import Sapphire

@Suite("Simplified Chinese lyrics")
struct LyricsSimplifiedChineseTests {
    @Test("Converts Traditional text and words while keeping IDs and timing")
    func convertsTraditionalLyrics() throws {
        let line = LyricLine(
            text: "說好的幸福",
            timestamp: 1,
            endTimestamp: 3,
            words: [
                LyricWord(text: "說好的", timestamp: 1, endTimestamp: 2),
                LyricWord(text: "幸福", timestamp: 2, endTimestamp: 3),
            ]
        )

        let converted = try #require([line].convertedToSimplifiedChinese().first)

        #expect(converted.id == line.id)
        #expect(converted.text == "说好的幸福")
        #expect(converted.words.map(\.text) == ["说好的", "幸福"])
        #expect(converted.words.map(\.id) == line.words.map(\.id))
        #expect(converted.hasReconstructibleWordTiming)
    }

    @Test("Leaves Japanese songs untouched, including kana-free lines")
    func leavesJapaneseSongsUntouched() {
        let lyrics = [
            LyricLine(text: "國境の長いトンネル", timestamp: 1),
            LyricLine(text: "雪國", timestamp: 2),
        ]

        #expect(lyrics.convertedToSimplifiedChinese().map(\.text) == ["國境の長いトンネル", "雪國"])
    }
}
