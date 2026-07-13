import UIKit

/// Curated, recognizable SF Symbols for tile icons — creatures, sky, music,
/// fun, sports, vehicles, food. Filtered at runtime against the installed
/// symbol set so a bad name can never render as a blank tile.
enum SymbolCatalog {
    static let symbols: [String] = [
        // Creatures
        "lizard.fill", "bird.fill", "fish.fill", "tortoise.fill", "hare.fill",
        "dog.fill", "cat.fill", "pawprint.fill", "ladybug.fill", "ant.fill",
        "teddybear.fill",
        // Sky and nature
        "sun.max.fill", "moon.stars.fill", "cloud.fill", "cloud.rain.fill",
        "snowflake", "rainbow", "star.fill", "sparkles", "flame.fill",
        "bolt.fill", "leaf.fill", "tree.fill", "drop.fill", "heart.fill",
        // Music
        "music.note", "guitars.fill", "music.mic", "headphones", "radio.fill",
        // Fun
        "gamecontroller.fill", "balloon.2.fill", "party.popper.fill",
        "gift.fill", "crown.fill", "birthday.cake.fill", "wand.and.stars",
        "paintpalette.fill", "theatermasks.fill", "camera.fill", "book.fill",
        "house.fill", "figure.dance",
        // Sports and vehicles
        "basketball.fill", "soccerball", "baseball.fill", "football.fill",
        "tennisball.fill", "bicycle", "car.fill", "airplane", "tram.fill",
        "sailboat.fill", "train.side.front.car",
        // Food
        "cup.and.saucer.fill", "fork.knife", "carrot.fill", "popcorn.fill",
    ].filter { UIImage(systemName: $0) != nil }

    /// "sun.max.fill" → "sun max" for VoiceOver.
    static func spokenName(_ symbol: String) -> String {
        symbol
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
    }
}
