import SwiftUI

enum GameCatalog {

    struct Game: Identifiable, Hashable {
        let id: String
        let name: String
        let category: GameCategory
        let iconName: String
        var customImageName: String? = nil
        let shortDescription: String
        let rules: [String]
        let scienceExplainer: String
        var isLocked: Bool = false
    }

    static let games: [Game] = [
        Game(
            id: "memory_matrix",
            name: "Memory Matrix",
            category: .memory,
            iconName: "square.grid.3x3.fill",
            customImageName: "matrix",
            shortDescription: "Match hidden pairs before time runs out.",
            rules: [
                "A grid of cards flips face-down after a brief preview.",
                "Tap two cards to flip them and find a matching pair.",
                "Match every pair before the timer runs out.",
                "Fewer wrong flips means a higher score."
            ],
            scienceExplainer: "Memory Matrix trains your visuospatial working memory — the system that briefly holds and manipulates spatial information. Repeatedly encoding card positions and retrieving them under time pressure strengthens the hippocampal and prefrontal circuits linked to short-term recall."
        ),
        Game(
            id: "speed_match",
            name: "Speed Match",
            category: .speed,
            iconName: "bolt.fill",
            customImageName: "speed",
            shortDescription: "React fast to spot the matching pattern.",
            rules: [
                "Two symbols appear on screen at once.",
                "Tap Match or No Match as fast as you can.",
                "Speed and accuracy both count toward your score.",
                "The pace picks up the longer you last."
            ],
            scienceExplainer: "Speed Match targets processing speed — how quickly your brain can take in information and decide on a response. Faster, accurate reactions under pressure reflect efficient signal transmission between neurons, a skill that tends to decline with age but responds well to training."
        ),
        Game(
            id: "lost_in_migration",
            name: "Lost in Migration",
            category: .attention,
            iconName: "scope",
            customImageName: "arrow",
            shortDescription: "Spot the bird flying against the flock.",
            rules: [
                "A flock of birds flies in one direction.",
                "One bird faces a different way — tap it.",
                "Ignore the distractors around it.",
                "React quickly for bonus points."
            ],
            scienceExplainer: "This game exercises selective attention — your ability to focus on one relevant detail while filtering out surrounding noise. It's the same mechanism you rely on to notice a single important sign in a cluttered scene, and it's directly trainable through repeated practice.",
            isLocked: true
        ),
        Game(
            id: "brain_shift",
            name: "Brain Shift",
            category: .flexibility,
            iconName: "arrow.left.arrow.right",
            customImageName: "shift",
            shortDescription: "Switch rules on the fly without slipping up.",
            rules: [
                "You'll sort items by one rule, like color.",
                "The rule swaps to something new without warning, like shape.",
                "Watch the prompt closely and adapt fast.",
                "Slipping back to the old rule costs you points."
            ],
            scienceExplainer: "Brain Shift builds cognitive flexibility — the capacity to switch between mental rules or tasks smoothly. This is governed largely by the prefrontal cortex and underlies real-world skills like multitasking and adapting quickly when a plan suddenly changes.",
            isLocked: true
        ),
        Game(
            id: "pirate_passage",
            name: "Pirate Passage",
            category: .problemSolving,
            iconName: "map.fill",
            customImageName: "pirate",
            shortDescription: "Plan a route through shifting obstacles.",
            rules: [
                "Guide the ship from start to the treasure.",
                "Plan your route around rocks and obstacles.",
                "Fewer moves earns a better score.",
                "Think a few steps ahead before moving."
            ],
            scienceExplainer: "Pirate Passage strengthens planning and problem-solving — mapping out several moves ahead before acting. This kind of forward-thinking relies on executive function circuits that also support everyday decisions like budgeting time or navigating a new route.",
            isLocked: true
        ),
            Game(
            id: "splitting_seeds",
            name: "Splitting Seeds",
            category: .math,
            iconName: "divide.circle.fill",
            customImageName: "bird",
            shortDescription: "Split totals quickly under time pressure.",
            rules: [
                "A total number of seeds appears on screen.",
                "Split it evenly between the baskets shown.",
                "Answer as many rounds as you can before time's up.",
                "Wrong splits reset your streak."
            ],
            scienceExplainer: "Splitting Seeds keeps numerical reasoning sharp by asking you to manipulate quantities quickly and accurately. Mental arithmetic under time pressure engages working memory alongside number sense, both of which are strongly tied to everyday tasks like budgeting or estimating.",
            isLocked: true
        ),
    ]
}


extension GameCatalog {
    static var todaysGames: [Game] {
        GameCategory.allCases.compactMap { category in
            games.first(where: { $0.category == category })
        }
    }

    static func games(in category: GameCategory) -> [Game] {
        games.filter { $0.category == category }
    }
}
