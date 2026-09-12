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
            shortDescription: "Memorize the lit-up tiles, then tap them from memory.",
            rules: [
                "A few tiles briefly light up on the grid.",
                "Memorize their positions before they disappear.",
                "Tap every tile you remember was highlighted.",
                "One wrong tap ends the round — the grid grows harder each level."
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
    "Plan your full route before you move — tap tiles to build the path.",
    "Watch each pirate's patrol route and time your path around them.",
    "Fewer moves earns a better score, with a bonus for the optimal path."
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

        Game(
            id: "train_of_thought",
            name: "Train of Thought",
            category: .attention,
            iconName: "tram.fill",
            shortDescription: "Route trains to their matching stations.",
            rules: [
                "Trains enter and travel the tracks automatically.",
                "Tap a switch to send the next train down the right branch.",
                "Match each train's color to its station.",
                "Wrong stations and crashes cost points."
            ],
            scienceExplainer: "Train of Thought trains divided attention — tracking several independent moving objects at once and acting on the right one at the right time. This is the same skill you use merging into traffic while watching multiple cars, and it's directly trainable through repeated practice.",
            isLocked: true
        ),


        Game(
            id: "flow_switch",
            name: "Flow Switch",
            category: .flexibility,
            iconName: "leaf.fill",
            shortDescription: "Follow the color's rule as leaves point one way and drift another.",
            rules: [
                "Green leaves: respond to which way they're pointing.",
                "Orange leaves: respond to which way they're drifting.",
                "The two directions won't always match — ignore the wrong one.",
                "The rule can switch color at any moment, so stay sharp."
            ],
            scienceExplainer: "Flow Switch trains cognitive flexibility and inhibitory control together: you must suppress an irrelevant direction cue while following the one your current rule calls for, then re-orient the moment the rule switches. This tug-of-war between competing signals mirrors everyday task-switching, like glancing at a text while driving and having to redirect attention instantly.",
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
