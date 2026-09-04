import SwiftUI

enum DiscoverCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case memory = "Memory"
    case brainHealth = "Brain Health"
    case attention = "Attention"
    case mythsFacts = "Myths & Facts"
    case research = "Research & Evidence"
    case brainBasics = "Brain Basics"
    case inRealLife = "In Real Life"
    case insideLumiMind = "Inside LumiMind"

    var id: String { rawValue }

    var gradient: LinearGradient {
        switch self {
        case .memory:         return DesignSystem.memoryGradient
        case .brainHealth:    return DesignSystem.mathGradient
        case .attention:      return DesignSystem.attentionGradient
        case .mythsFacts:     return DesignSystem.speedGradient
        case .research:       return DesignSystem.flexibilityGradient
        case .brainBasics:    return DesignSystem.primaryGradient
        case .inRealLife:     return DesignSystem.problemSolvingGradient
        case .insideLumiMind: return DesignSystem.spotlightGradient
        }
    }
}

struct DiscoverArticle: Identifiable, Hashable {
    let id: String
    let category: DiscoverCategory
    let title: String
    let subtitle: String
    let bodyIntro: String
    let bodyHighlight: String
    let sourceCitation: String?
    let isForYou: Bool
}

enum DiscoverCatalog {
    static let articles: [DiscoverArticle] = [
        DiscoverArticle(id: "short_term_memory", category: .memory,
            title: "What is Short-Term Memory?", subtitle: "Your brain's sticky note for things you need right now",
            bodyIntro: "Short-term memory holds a handful of items — a phone number, a name, a shopping list — for roughly 20 to 30 seconds before they fade or get pushed out by something new.",
            bodyHighlight: "It's not a smaller version of long-term memory. It's a separate system with its own limited capacity, which is why juggling too many things at once makes you drop one.",
            sourceCitation: "Miller, G. A. (1956). The magical number seven, plus or minus two. Psychological Review, 63(2), 81–97.",
            isForYou: true),

        DiscoverArticle(id: "forty_percent_stat", category: .brainHealth,
            title: "The 40% Stat", subtitle: "The lifestyle factors that shape brain health",
            bodyIntro: "Researchers estimate a substantial share of dementia risk traces back to modifiable lifestyle factors — not genetics.",
            bodyHighlight: "Sleep, exercise, social connection, and cardiovascular health all move the needle. None of it guarantees an outcome, but the direction is consistent across decades of studies.",
            sourceCitation: "Livingston, G. et al. (2020). Dementia prevention, intervention, and care. The Lancet Commission.",
            isForYou: true),

        DiscoverArticle(id: "how_games_designed", category: .insideLumiMind,
            title: "How Games Are Designed", subtitle: "Turning lab tasks into daily practice",
            bodyIntro: "Every LumiMind game starts as a cognitive task used in research labs — tasks that measure things like working memory span or processing speed.",
            bodyHighlight: "Our team reshapes each one into something you'd actually choose to play, while keeping the underlying mechanic that makes it measurable.",
            sourceCitation: nil, isForYou: false),

        DiscoverArticle(id: "what_is_lpi", category: .insideLumiMind,
            title: "What Is LPI?", subtitle: "LumiMind's way of measuring your progress",
            bodyIntro: "Your LumiMind Performance Index (LPI) turns results across every game category into one trackable number.",
            bodyHighlight: "It moves as your scores do, so you can see whether a category is trending up over weeks, not just after a single session.",
            sourceCitation: nil, isForYou: false),

        DiscoverArticle(id: "sleep_and_brain", category: .brainHealth,
            title: "Sleep & Your Brain", subtitle: "What happens while you're asleep",
            bodyIntro: "Sleep isn't downtime for the brain — it's when short-term memories get sorted and filed into longer-term storage.",
            bodyHighlight: "Deep sleep in particular is linked to memory consolidation, which is part of why a bad night can leave yesterday feeling foggy.",
            sourceCitation: "Walker, M. P. (2009). The role of sleep in cognition and emotion. Annals of the NY Academy of Sciences.",
            isForYou: false),

        DiscoverArticle(id: "exercise_and_brain", category: .brainHealth,
            title: "Exercise & Your Brain", subtitle: "Why moving your body helps your mind",
            bodyIntro: "Aerobic exercise increases blood flow to the brain and is associated with growth in the hippocampus, a region central to memory.",
            bodyHighlight: "You don't need an intense routine — consistent moderate activity shows measurable benefits across studies.",
            sourceCitation: "Erickson, K. I. et al. (2011). Exercise training increases size of hippocampus. PNAS.",
            isForYou: false),

        DiscoverArticle(id: "multitasking_myth", category: .mythsFacts,
            title: "The Multitasking Myth", subtitle: "Why your brain can't actually multitask",
            bodyIntro: "What feels like doing two things at once is usually your attention switching rapidly back and forth between them.",
            bodyHighlight: "Each switch carries a small cost. String enough together and you're slower and more error-prone than doing tasks one at a time.",
            sourceCitation: "Monsell, S. (2003). Task switching. Trends in Cognitive Sciences, 7(3), 134–140.",
            isForYou: false),

        DiscoverArticle(id: "ten_percent_myth", category: .mythsFacts,
            title: "Do We Only Use 10%?", subtitle: "What brain imaging really shows",
            bodyIntro: "The idea that we only use 10% of our brain is a popular myth with no basis in neuroscience.",
            bodyHighlight: "Brain scans show activity distributed across virtually the entire brain over a day — different regions simply activate for different tasks.",
            sourceCitation: nil, isForYou: false),

        DiscoverArticle(id: "studies_on_lumimind", category: .research,
            title: "Studies on LumiMind", subtitle: "Peer-reviewed research and counting",
            bodyIntro: "The training approach behind LumiMind draws on a growing body of published cognitive science research.",
            bodyHighlight: "We track new findings as they're published and use them to inform how games evolve.",
            sourceCitation: nil, isForYou: false),

        DiscoverArticle(id: "air_quality_cognition", category: .research,
            title: "Air Quality & Cognition", subtitle: "How the air you breathe affects thinking",
            bodyIntro: "Several studies link short-term exposure to poor air quality with measurable dips in cognitive test performance.",
            bodyHighlight: "The effect is usually temporary, but it's a reminder that brain performance isn't purely a matter of practice.",
            sourceCitation: "Zhang, X. et al. (2018). Impact of exposure to air pollution on cognitive performance. PNAS.",
            isForYou: false),

        DiscoverArticle(id: "why_memories_compete", category: .brainBasics,
            title: "Why Memories Compete", subtitle: "When old knowledge crowds out new (and vice versa)",
            bodyIntro: "Learning something new can make it harder to recall something old, and old memories can interfere with encoding new ones.",
            bodyHighlight: "Psychologists call this interference — it's less about forgetting and more about memories competing for the same retrieval cues.",
            sourceCitation: "Anderson, M. C. & Neely, J. H. (1996). Interference and inhibition in memory retrieval.",
            isForYou: false),

        DiscoverArticle(id: "chunking", category: .brainBasics,
            title: "How Chunking Helps You Remember More", subtitle: "The trick that compresses memory load",
            bodyIntro: "Chunking groups individual pieces of information into larger, meaningful units — turning ten digits into three familiar clusters.",
            bodyHighlight: "A phone number is easier to recall as three chunks than ten separate digits — you're remembering fewer things, not more.",
            sourceCitation: "Miller, G. A. (1956). The magical number seven, plus or minus two.",
            isForYou: false),

        DiscoverArticle(id: "lose_your_keys", category: .inRealLife,
            title: "Why You Lose Your Keys", subtitle: "It's not forgetting. It's never remembering.",
            bodyIntro: "You didn't forget where you put your keys — your brain never turned that moment into a memory in the first place. Encoding depends heavily on attention, and if your mind is elsewhere when you set them down, there's nothing to retrieve later.",
            bodyHighlight: "The same thing happens with a coffee cup or a name you just heard. The fix isn't trying harder to remember — it's giving the action a fixed, repeatable spot so habit does the remembering for you.",
            sourceCitation: "Craik, F. I. M., Govoni, R., Naveh-Benjamin, M., & Anderson, N. D. (1996). Effects of divided attention on encoding and retrieval. J. Exp. Psych: General, 125(2), 159–180.",
            isForYou: false),

        DiscoverArticle(id: "tip_of_tongue", category: .inRealLife,
            title: "The Tip of Your Tongue", subtitle: "The word is there. The path to it isn't.",
            bodyIntro: "The tip-of-the-tongue state happens when a memory is fully stored but the retrieval path to it temporarily breaks down.",
            bodyHighlight: "You can often recall the first letter or how many syllables it has — a sign the word exists in memory, just not fully accessible yet.",
            sourceCitation: "Brown, R. & McNeill, D. (1966). The tip of the tongue phenomenon.",
            isForYou: false),

                DiscoverArticle(id: "working_memory", category: .memory,
            title: "What is Working Memory?", subtitle: "The mental workspace you use right now",
            bodyIntro: "Working memory is the small amount of information you can actively hold and manipulate at once — like doing math in your head.",
            bodyHighlight: "Unlike short-term memory, which just stores, working memory lets you operate on information — reorder it, compare it, use it.",
            sourceCitation: "Baddeley, A. (1992). Working memory. Science, 255(5044), 556–559.",
            isForYou: false),

        DiscoverArticle(id: "spacing_effect", category: .memory,
            title: "The Spacing Effect", subtitle: "Why cramming doesn't stick",
            bodyIntro: "Spreading practice across several sessions produces stronger, longer-lasting memories than one long cram session.",
            bodyHighlight: "Each time you retrieve a memory after a gap, it gets reinforced more than repeating it immediately.",
            sourceCitation: "Cepeda, N. J. et al. (2006). Distributed practice in verbal recall tasks.",
            isForYou: false),

        DiscoverArticle(id: "false_memories", category: .memory,
            title: "How False Memories Form", subtitle: "Why confident recall isn't always accurate",
            bodyIntro: "Memory isn't a recording — it's reconstructed each time you recall it, which leaves room for details to shift or blend with other memories.",
            bodyHighlight: "People can feel completely certain about a memory that's partly or entirely wrong.",
            sourceCitation: "Loftus, E. F. (2005). Planting misinformation in the human mind.",
            isForYou: false),

        DiscoverArticle(id: "stress_and_brain", category: .brainHealth,
            title: "Stress & Your Brain", subtitle: "What chronic stress does to memory",
            bodyIntro: "Short bursts of stress can sharpen focus, but prolonged stress raises cortisol in ways linked to hippocampal shrinkage over time.",
            bodyHighlight: "Recovery matters more than avoiding stress entirely — consistent downtime protects the same regions stress affects.",
            sourceCitation: "McEwen, B. S. (2007). Physiology and neurobiology of stress and adaptation.",
            isForYou: false),

        DiscoverArticle(id: "selective_attention", category: .attention,
            title: "Selective Attention", subtitle: "How your brain filters the noise",
            bodyIntro: "At any moment your senses take in far more than you can consciously process, so attention acts as a filter, prioritizing what matters.",
            bodyHighlight: "This is why you can hear your name across a loud room — the filter stays tuned to relevant signals even when you're not focused on them.",
            sourceCitation: "Cherry, E. C. (1953). Some experiments on the recognition of speech.",
            isForYou: false),

        DiscoverArticle(id: "attention_span_myth", category: .attention,
            title: "The Attention Span Myth", subtitle: "Why the '8 seconds' claim is wrong",
            bodyIntro: "The often-cited claim that human attention spans are shorter than a goldfish's has no credible research behind it.",
            bodyHighlight: "Attention is task-dependent — it varies hugely by what you're doing and how engaging it is, not a single fixed number.",
            sourceCitation: nil, isForYou: false),

        DiscoverArticle(id: "divided_attention", category: .attention,
            title: "Divided Attention", subtitle: "What splitting focus actually costs",
            bodyIntro: "When attention splits across two tasks, performance on both typically drops — especially if either task requires conscious thought.",
            bodyHighlight: "Practiced, automatic tasks (like walking) interfere less than tasks that need active decision-making.",
            sourceCitation: "Pashler, H. (1994). Dual-task interference in simple tasks.",
            isForYou: false),

        DiscoverArticle(id: "left_brain_myth", category: .mythsFacts,
            title: "Left Brain, Right Brain?", subtitle: "What the hemispheres actually do",
            bodyIntro: "The idea that people are 'left-brained' (logical) or 'right-brained' (creative) oversimplifies how the brain works.",
            bodyHighlight: "Most complex tasks — including creativity and logic — recruit both hemispheres working together.",
            sourceCitation: "Nielsen, J. A. et al. (2013). An evaluation of the left-brain vs. right-brain hypothesis.",
            isForYou: false),

        DiscoverArticle(id: "brain_games_research", category: .research,
            title: "Do Brain Games Work?", subtitle: "What the evidence actually says",
            bodyIntro: "Research shows consistent improvement on the specific game trained, with more debate over how far those gains transfer elsewhere.",
            bodyHighlight: "The strongest evidence supports near-transfer — improvement in closely related skills — over broad, general intelligence gains.",
            sourceCitation: "Simons, D. J. et al. (2016). Do brain-training programs work?",
            isForYou: false),

        DiscoverArticle(id: "neuroplasticity", category: .brainBasics,
            title: "What Is Neuroplasticity?", subtitle: "Your brain's ability to rewire itself",
            bodyIntro: "Neuroplasticity is the brain's capacity to form new neural connections throughout life, not just in childhood.",
            bodyHighlight: "Repeated practice strengthens specific pathways — which is the basic mechanism behind why training a skill improves it.",
            sourceCitation: "Draganski, B. et al. (2004). Neuroplasticity: changes in grey matter induced by training.",
            isForYou: false),

        DiscoverArticle(id: "forgetting_curve", category: .brainBasics,
            title: "The Forgetting Curve", subtitle: "How fast new information fades",
            bodyIntro: "Without reinforcement, newly learned information decays fast — most of it within the first day.",
            bodyHighlight: "Each timed review flattens the curve, which is why spaced repetition beats one-time exposure.",
            sourceCitation: "Ebbinghaus, H. (1885). Memory: A Contribution to Experimental Psychology.",
            isForYou: false),

        DiscoverArticle(id: "deja_vu", category: .inRealLife,
            title: "What Causes Déjà Vu", subtitle: "That eerie feeling of 'I've been here before'",
            bodyIntro: "Déjà vu likely happens when a new experience partially overlaps with a stored memory, tricking the brain into a false sense of familiarity.",
            bodyHighlight: "It's common, brief, and considered a normal quirk of memory — not a sign anything is wrong.",
            sourceCitation: "Cleary, A. M. (2008). Recognition memory, familiarity, and déjà vu experiences.",
            isForYou: false),

        DiscoverArticle(id: "name_forgetting", category: .inRealLife,
            title: "Why You Forget Names Instantly", subtitle: "The most common memory complaint there is",
            bodyIntro: "Names are abstract and arbitrary compared to faces, which carry rich visual detail — so they're encoded far more weakly by default.",
            bodyHighlight: "Repeating a name right after hearing it, or linking it to something visual, gives it the extra encoding it needs to stick.",
            sourceCitation: "McWeeny, K. H. et al. (1987). Putting names to faces.",
            isForYou: false),

        DiscoverArticle(id: "science_behind_scoring", category: .insideLumiMind,
            title: "The Science Behind Your Score", subtitle: "What each game is actually measuring",
            bodyIntro: "Every result you see maps back to a specific cognitive domain — speed, memory span, or flexibility — not a single vague 'brain score.'",
            bodyHighlight: "That's why your category scores can move independently — improving at Speed doesn't automatically move Memory.",
            sourceCitation: nil, isForYou: false),

        DiscoverArticle(id: "difficulty_adapts", category: .insideLumiMind,
            title: "Why Difficulty Adapts", subtitle: "How each game adjusts to you",
            bodyIntro: "LumiMind games adjust difficulty based on your recent performance, aiming to keep each session challenging but achievable.",
            bodyHighlight: "This mirrors a well-established training principle: growth happens fastest just past your current comfort level.",
            sourceCitation: nil, isForYou: false)    
    ]
}