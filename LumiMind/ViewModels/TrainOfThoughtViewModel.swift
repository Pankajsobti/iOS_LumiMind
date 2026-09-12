import Foundation
import CoreGraphics
import Combine

// MARK: - TrainOfThoughtViewModel
//
// Owns gameplay state for Train of Thought: trains spawn from two
// entry points, travel a fixed (validated, always-solvable) track
// network through a shared switch tree, and must reach the station
// matching their color. Player toggles switches before an
// approaching train reaches them. Continuous divided-attention loop
// rather than discrete rounds — mirrors LostInMigrationViewModel's
// conventions (View only renders published state; this ViewModel
// submits the result itself the moment the round timer ends).

@MainActor
final class TrainOfThoughtViewModel: ObservableObject {

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    struct TrackSegment {
        enum Destination: Equatable {
            case switchNode(String)
            case station(String)
        }
        let id: String
        let points: [CGPoint]
        let destination: Destination
    }

    struct SwitchState: Identifiable, Equatable {
        let id: String
        let position: CGPoint
        var activeBranch: Int
        let branchSegmentIds: [String]
    }

    struct StationState: Identifiable {
        let id: String
        let position: CGPoint
        let colorHex: String
    }

    struct TrainState: Identifiable, Equatable {
        let id: Int
        let destinationId: String
        let colorHex: String
        var currentSegmentId: String
        var progress: Double
        let speed: Double
    }

    // MARK: Tunables

    static let roundDurationSeconds: Double = 60
    static let collisionThreshold: CGFloat = 24
    static let baseSpawnInterval: Double = 3.2
    static let minSpawnInterval: Double = 1.3
    static let baseSpeed: Double = 55
    static let maxSpeed: Double = 105

    /// Streak-tracking tunables for the Flow-Switch-style stat bar.
    /// These only drive the on-screen meter/multiplier — they never
    /// alter the point values awarded in advanceTrains/detectCollisions.
    static let meterMax: Int = 5
    static let maxMultiplier: Int = 8

    // MARK: Fixed, pre-validated track network
    //
    // A single hand-built template graph. Both entry points feed into
    // a shared trunk switch (s0), which in turn feeds a shared switch
    // tree (s1, s2, s3) down to five stations — so every station is
    // reachable from every entry point via at least one switch
    // configuration, no matter which entry a train spawned from. This
    // stands in for a full procedural-graph + reachability validator
    // (see optional enhancements).

    static let stations: [StationState] = [
        StationState(id: "red",    position: CGPoint(x: 25,  y: 430), colorHex: "#FF5E5B"),
        StationState(id: "blue",   position: CGPoint(x: 100, y: 430), colorHex: "#4A7BFF"),
        StationState(id: "green",  position: CGPoint(x: 170, y: 430), colorHex: "#2ECC71"),
        StationState(id: "orange", position: CGPoint(x: 240, y: 430), colorHex: "#FF8A3D"),
        StationState(id: "purple", position: CGPoint(x: 315, y: 430), colorHex: "#9B6BFF")
    ]

    static let segments: [String: TrackSegment] = {
        var s: [String: TrackSegment] = [:]
        // Entries converge into the shared trunk switch s0.
        s["e1"] = TrackSegment(id: "e1", points: [CGPoint(x: 60, y: 20), CGPoint(x: 170, y: 130)], destination: .switchNode("s0"))
        s["e2"] = TrackSegment(id: "e2", points: [CGPoint(x: 280, y: 20), CGPoint(x: 170, y: 130)], destination: .switchNode("s0"))

        // Trunk splits into the two subtrees.
        s["s0_a"] = TrackSegment(id: "s0_a", points: [CGPoint(x: 170, y: 130), CGPoint(x: 95, y: 230)], destination: .switchNode("s1"))
        s["s0_b"] = TrackSegment(id: "s0_b", points: [CGPoint(x: 170, y: 130), CGPoint(x: 245, y: 230)], destination: .switchNode("s2"))

        // s1 -> red / blue
        s["s1_a"] = TrackSegment(id: "s1_a", points: [CGPoint(x: 95, y: 230), CGPoint(x: 25, y: 430)], destination: .station("red"))
        s["s1_b"] = TrackSegment(id: "s1_b", points: [CGPoint(x: 95, y: 230), CGPoint(x: 100, y: 430)], destination: .station("blue"))

        // s2 -> green directly, or down into s3
        s["s2_a"] = TrackSegment(id: "s2_a", points: [CGPoint(x: 245, y: 230), CGPoint(x: 170, y: 430)], destination: .station("green"))
        s["s2_b"] = TrackSegment(id: "s2_b", points: [CGPoint(x: 245, y: 230), CGPoint(x: 280, y: 320)], destination: .switchNode("s3"))

        // s3 -> orange / purple
        s["s3_a"] = TrackSegment(id: "s3_a", points: [CGPoint(x: 280, y: 320), CGPoint(x: 240, y: 430)], destination: .station("orange"))
        s["s3_b"] = TrackSegment(id: "s3_b", points: [CGPoint(x: 280, y: 320), CGPoint(x: 315, y: 430)], destination: .station("purple"))
        return s
    }()

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var trains: [TrainState] = []
    @Published private(set) var switches: [SwitchState] = [
        SwitchState(id: "s0", position: CGPoint(x: 170, y: 130), activeBranch: 0, branchSegmentIds: ["s0_a", "s0_b"]),
        SwitchState(id: "s1", position: CGPoint(x: 95, y: 230), activeBranch: 0, branchSegmentIds: ["s1_a", "s1_b"]),
        SwitchState(id: "s2", position: CGPoint(x: 245, y: 230), activeBranch: 0, branchSegmentIds: ["s2_a", "s2_b"]),
        SwitchState(id: "s3", position: CGPoint(x: 280, y: 320), activeBranch: 0, branchSegmentIds: ["s3_a", "s3_b"])
    ]
    @Published private(set) var timeRemainingFraction: Double = 1.0
    @Published private(set) var successCount: Int = 0
    @Published private(set) var mistakeCount: Int = 0
    @Published private(set) var collisionCount: Int = 0
    @Published private(set) var lastEventWasGood: Bool?

    /// Live score for the stat bar — mirrors runningScore, floored at
    /// 0 for display (final score is floored the same way at endGame).
    @Published private(set) var currentScore: Int = 0
    /// Streak meter + multiplier, purely for the stat bar — does not
    /// feed into the point values below.
    @Published private(set) var meter: Int = 0
    @Published private(set) var multiplier: Int = 1

    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    var timeRemainingLabel: String {
        let remaining = max(0, Self.roundDurationSeconds - elapsed)
        let clamped = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool
    private var loopTask: Task<Void, Never>?
    private var runningScore = 0
    private var elapsed: Double = 0
    private var nextSpawnAt: Double = 0.6
    private var nextTrainId = 0
    private var gameStartedAt: Date?

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        setUpNewGame()
    }

    // MARK: - Setup

    func setUpNewGame() {
        loopTask?.cancel()
        trains = []
        switches = switches.map { var s = $0; s.activeBranch = 0; return s }
        successCount = 0
        mistakeCount = 0
        collisionCount = 0
        runningScore = 0
        currentScore = 0
        meter = 0
        multiplier = 1
        elapsed = 0
        nextSpawnAt = 0.6
        nextTrainId = 0
        lastEventWasGood = nil
        timeRemainingFraction = 1.0
        phase = .playing
        gameStartedAt = Date()
        startLoop()
    }

    // MARK: - Player interaction

    func toggleSwitch(_ id: String) {
        guard phase == .playing, let idx = switches.firstIndex(where: { $0.id == id }) else { return }
        switches[idx].activeBranch = 1 - switches[idx].activeBranch
    }

    // MARK: - Game loop

    private func startLoop() {
        loopTask = Task { [weak self] in
            guard let self else { return }
            let dt = 1.0 / 30.0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(dt * 1_000_000_000))
                if Task.isCancelled { return }
                self.tick(dt: dt)
                if self.elapsed >= Self.roundDurationSeconds {
                    self.endGame()
                    return
                }
            }
        }
    }

    private func tick(dt: Double) {
        elapsed += dt
        timeRemainingFraction = max(0, 1 - elapsed / Self.roundDurationSeconds)
        let difficulty = min(1, elapsed / Self.roundDurationSeconds)

        if elapsed >= nextSpawnAt {
            spawnTrain(difficulty: difficulty)
            let interval = Self.baseSpawnInterval - (Self.baseSpawnInterval - Self.minSpawnInterval) * difficulty
            nextSpawnAt = elapsed + interval
        }

        advanceTrains(dt: dt, difficulty: difficulty)
        detectCollisions()
    }

    private func spawnTrain(difficulty: Double) {
        let entryId = Bool.random() ? "e1" : "e2"
        let destinationId = Self.stations.randomElement()!.id
        let color = Self.stations.first(where: { $0.id == destinationId })!.colorHex
        let speed = Self.baseSpeed + (Self.maxSpeed - Self.baseSpeed) * difficulty * Double.random(in: 0.85...1.15)
        trains.append(TrainState(id: nextTrainId, destinationId: destinationId, colorHex: color, currentSegmentId: entryId, progress: 0, speed: speed))
        nextTrainId += 1
    }

    /// Registers a successful routing against the streak meter/multiplier
    /// shown in the stat bar. Purely cosmetic bookkeeping — does not
    /// change the point value already applied to runningScore.
    private func registerStreakSuccess() {
        meter += 1
        if meter >= Self.meterMax {
            meter = 0
            multiplier = min(multiplier + 1, Self.maxMultiplier)
        }
    }

    /// Registers a miss (wrong station or collision) against the
    /// streak meter/multiplier, mirroring Flow Switch's rule: drop the
    /// partial meter first, and only reduce the multiplier once the
    /// meter is already empty.
    private func registerStreakMiss() {
        if meter > 0 {
            meter = 0
        } else {
            multiplier = max(multiplier - 1, 1)
        }
    }

    /// Scoring rule: a correctly routed train scores 40 points plus up
    /// to 30 more as a difficulty bonus that scales with elapsed-round
    /// progress (harder, later trains are worth more). A wrong
    /// destination costs 25. A collision costs 40 and removes both
    /// trains involved. Final score is floored at 0. Correct routing
    /// and sustained accuracy weigh more than raw speed, since the
    /// difficulty bonus only ever adds up to 75% on top of the flat
    /// success reward.
    private func advanceTrains(dt: Double, difficulty: Double) {
        var toRemove: Set<Int> = []
        for i in trains.indices {
            guard let seg = Self.segments[trains[i].currentSegmentId] else { continue }
            let len = Self.length(of: seg.points)
            trains[i].progress += trains[i].speed * dt / max(len, 1)
            guard trains[i].progress >= 1.0 else { continue }

            switch seg.destination {
            case .switchNode(let switchId):
                guard let sw = switches.first(where: { $0.id == switchId }) else { continue }
                trains[i].currentSegmentId = sw.branchSegmentIds[sw.activeBranch]
                trains[i].progress = 0
            case .station(let stationId):
                if stationId == trains[i].destinationId {
                    successCount += 1
                    runningScore += 40 + Int(30 * difficulty)
                    lastEventWasGood = true
                    registerStreakSuccess()
                } else {
                    mistakeCount += 1
                    runningScore -= 25
                    lastEventWasGood = false
                    registerStreakMiss()
                }
                currentScore = max(0, runningScore)
                toRemove.insert(trains[i].id)
            }
        }
        if !toRemove.isEmpty { trains.removeAll { toRemove.contains($0.id) } }
    }

    private func detectCollisions() {
        var removed: Set<Int> = []
        let bySegment = Dictionary(grouping: trains, by: { $0.currentSegmentId })
        for (segId, group) in bySegment where group.count > 1 {
            guard let seg = Self.segments[segId] else { continue }
            for a in 0..<group.count {
                for b in (a + 1)..<group.count {
                    let pa = Self.point(at: group[a].progress, on: seg.points)
                    let pb = Self.point(at: group[b].progress, on: seg.points)
                    if hypot(pa.x - pb.x, pa.y - pb.y) < Self.collisionThreshold {
                        removed.insert(group[a].id)
                        removed.insert(group[b].id)
                    }
                }
            }
        }
        if !removed.isEmpty {
            trains.removeAll { removed.contains($0.id) }
            collisionCount += 1
            runningScore -= 40
            lastEventWasGood = false
            registerStreakMiss()
            currentScore = max(0, runningScore)
        }
    }

    // MARK: - Game over + scoring

    private func endGame() {
        guard phase == .playing else { return }
        loopTask?.cancel()

        let score = max(0, runningScore)
        let duration = gameStartedAt.map { max(1, Int(Date().timeIntervalSince($0).rounded())) } ?? Int(Self.roundDurationSeconds)

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Train of Thought",
                category: "Attention",
                score: score,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: score)
        }
    }

    // MARK: - Geometry helpers

    static func length(of points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 0..<points.count - 1 {
            total += hypot(points[i + 1].x - points[i].x, points[i + 1].y - points[i].y)
        }
        return total
    }

    static func point(at t: Double, on points: [CGPoint]) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        let total = length(of: points)
        var target = CGFloat(max(0, min(1, t))) * total
        for i in 0..<points.count - 1 {
            let segLen = hypot(points[i + 1].x - points[i].x, points[i + 1].y - points[i].y)
            if target <= segLen || i == points.count - 2 {
                let f = segLen > 0 ? target / segLen : 0
                return CGPoint(x: points[i].x + (points[i + 1].x - points[i].x) * f,
                               y: points[i].y + (points[i + 1].y - points[i].y) * f)
            }
            target -= segLen
        }
        return points.last!
    }
}