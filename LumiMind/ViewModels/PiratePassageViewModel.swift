import Foundation
import Combine

// MARK: - PiratePassageViewModel
//
// Full rewrite matching the "plan then execute" Pirate Passage spec:
// the player builds a complete path from START to the treasure before
// anything moves. Pressing GO animates the ship and every pirate's
// patrol simultaneously, tick by tick, checking both same-cell and
// crossing collisions at each step. Score rewards fewer moves over
// fewer seconds — planning efficiency, not reaction speed.
//
// Levels are static, hand-picked data (grid, obstacles, patrol
// routes) rather than fully random generation, per the spec's
// "predefined color-coded patrol route" language. Each level's data
// below was generated *and* validated offline with the same
// (row, col, tick) BFS model used here for `computeSafePath`, so every
// level is guaranteed solvable and — for levels 2-5 — actually
// requires a detour/backtrack around a pirate, not just a straight
// static-shortest-path walk.

@MainActor
final class PiratePassageViewModel: ObservableObject {

    // MARK: - Core types

    struct Position: Hashable {
        let row: Int
        let col: Int
    }

    enum PatrolKind {
        case loop
        case pingPong
    }

    /// An enemy ship's predefined, color-coded patrol.
    struct Patrol: Identifiable {
        let id: Int
        let name: String        // e.g. "Crimson Raider" — used in collision messages
        let colorHex: String
        let cells: [Position]   // ordered waypoints; consecutive cells must be adjacent
        let kind: PatrolKind
        let phase: Int          // tick offset, staggers pirates that share a route shape

        var period: Int {
            switch kind {
            case .loop:     return max(1, cells.count)
            case .pingPong: return cells.count <= 1 ? 1 : 2 * (cells.count - 1)
            }
        }

        /// Where this pirate sits at a given absolute tick. Pure
        /// function of tick — this is what lets the player (and the
        /// solver) predict a future position instead of only reacting
        /// to where the pirate is *right now*.
        func position(atTick tick: Int) -> Position {
            guard cells.count > 1 else { return cells.first ?? Position(row: 0, col: 0) }
            let p = period
            let t = (((tick + phase) % p) + p) % p
            switch kind {
            case .loop:
                return cells[t % cells.count]
            case .pingPong:
                return t < cells.count ? cells[t] : cells[p - t]
            }
        }
    }

    struct GridCell: Identifiable, Equatable {
        let id: Int
        let position: Position
        let isObstacle: Bool
        let isStart: Bool
        let isEnd: Bool
    }

    private struct Level {
        let rows: Int
        let cols: Int
        let cells: [GridCell]
        let start: Position
        let end: Position
        let obstacles: Set<Position>
        let optimalMoves: Int     // static BFS shortest path, ignoring pirates (scoring baseline)
        let pirates: [Patrol]
        let cellLookup: [Position: GridCell]
    }

    /// Summary shown on the success/failure overlay.
    struct LevelResult: Equatable {
        let success: Bool
        let movesUsed: Int
        let optimalMoves: Int
        let bonus: Int
        let levelScore: Int
        let attempt: Int
        let collisionReason: String?
        let usedHint: Bool
    }

    enum Phase: Equatable {
        case planning
        case executing
        case levelResult(LevelResult)
        case submitting
        case finished(score: Int)
    }

    // MARK: - Tunables

    static let totalLevels = 5
    private static let tickDuration: Double = 0.5 // seconds per simulated move, both ship & pirates
    private static let basePointsPerLevel = 100
    private static let optimalBonusPoints = 50
    private static let penaltyPerExtraMove = 6
    private static let secondAttemptMultiplier = 0.6
    private static let pirateColorPalette = [
        (hex: "#FF5E5B", name: "Crimson Raider"),   // reused from speedGradient
        (hex: "#F857A6", name: "Magenta Marauder"), // reused from flexibilityGradient
        (hex: "#2ECC71", name: "Emerald Enforcer")  // reused from mathGradient
    ]

    // MARK: - Published state

    @Published private(set) var phase: Phase = .planning
    @Published private(set) var levelIndex: Int = 0
    @Published private(set) var attempt: Int = 1
    @Published private(set) var rows: Int = 5
    @Published private(set) var cols: Int = 5
    @Published private(set) var cells: [GridCell] = []
    @Published private(set) var pirates: [Patrol] = []
    @Published private(set) var currentPath: [Position] = []
    @Published private(set) var hintPath: [Position]?
    @Published private(set) var runningScore: Int = 0

    /// Live, tick-indexed positions during GO execution — the view
    /// animates the ship/pirates toward these with `.animation`.
    @Published private(set) var executionTick: Int = 0
    @Published private(set) var animatedShipPosition: Position = Position(row: 0, col: 0)
    @Published private(set) var animatedPiratePositions: [Position] = []

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    var movesUsed: Int { max(0, currentPath.count - 1) }
    var canUndo: Bool { phase == .planning && currentPath.count > 1 }
    var canGo: Bool { phase == .planning && currentPath.last == currentLevel?.end && currentPath.count > 1 }

    // MARK: - Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool
    private var levels: [Level] = []
    private var currentLevel: Level!
    private var executionTask: Task<Void, Never>?
    private var gameStartedAt: Date?
    private var totalScore: Int = 0

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        setUpNewGame()
    }

    // MARK: - Setup

    func setUpNewGame() {
        executionTask?.cancel()
        totalScore = 0
        runningScore = 0
        levelIndex = 0
        levels = Self.buildLevels()
        phase = .planning
        gameStartedAt = Date()
        beginLevel(at: 0)
    }

    private func beginLevel(at index: Int) {
        guard index < levels.count else {
            endGame()
            return
        }
        executionTask?.cancel()

        levelIndex = index
        attempt = 1
        currentLevel = levels[index]
        rows = currentLevel.rows
        cols = currentLevel.cols
        cells = currentLevel.cells
        pirates = currentLevel.pirates
        currentPath = [currentLevel.start]
        hintPath = nil
        executionTick = 0
        animatedShipPosition = currentLevel.start
        animatedPiratePositions = currentLevel.pirates.map { $0.position(atTick: 0) }
        phase = .planning
    }

    // MARK: - Level data (generated + validated offline; see note above)

    private static func buildLevels() -> [Level] {
        [
            makeLevel(
                rows: 5, cols: 5,
                obstacles: [],
                start: Position(row: 0, col: 0), end: Position(row: 4, col: 4),
                patrolDefs: [
                    (cells: [(1,2),(0,2),(0,3)], kind: .pingPong, phase: 4)
                ]
            ),
            makeLevel(
                rows: 6, cols: 6,
                obstacles: [],
                start: Position(row: 0, col: 0), end: Position(row: 5, col: 5),
                patrolDefs: [
                    (cells: [(5,5),(4,5),(4,4),(4,3),(4,2)], kind: .pingPong, phase: 6)
                ]
            ),
            makeLevel(
                rows: 6, cols: 6,
                obstacles: [(0,3),(5,1),(5,4)],
                start: Position(row: 0, col: 0), end: Position(row: 5, col: 5),
                patrolDefs: [
                    (cells: [(1,0),(1,1),(1,2),(0,2),(0,1)], kind: .pingPong, phase: 7),
                    (cells: [(1,1),(2,1),(2,2),(1,2),(1,3)], kind: .pingPong, phase: 10)
                ]
            ),
            makeLevel(
                rows: 7, cols: 7,
                obstacles: [(5,6)],
                start: Position(row: 0, col: 0), end: Position(row: 6, col: 6),
                patrolDefs: [
                    (cells: [(6,6),(6,5),(6,4),(5,4)], kind: .pingPong, phase: 6),
                    (cells: [(1,0),(1,1),(0,1),(0,2),(0,3),(0,4)], kind: .pingPong, phase: 7)
                ]
            ),
            makeLevel(
                rows: 7, cols: 7,
                obstacles: [(0,4),(1,3),(1,5),(1,6),(2,3),(3,4),(5,3),(6,2)],
                start: Position(row: 0, col: 0), end: Position(row: 6, col: 6),
                patrolDefs: [
                    (cells: [(4,2),(4,3),(4,4),(5,4),(6,4),(6,5),(5,5)], kind: .pingPong, phase: 2),
                    (cells: [(5,4),(6,4),(6,5),(5,5),(4,5),(4,4),(4,3),(4,2)], kind: .pingPong, phase: 3),
                    (cells: [(5,0),(4,0),(4,1),(5,1),(6,1),(6,0)], kind: .pingPong, phase: 0)
                ]
            )
        ]
    }

    private static func makeLevel(
        rows: Int, cols: Int,
        obstacles obstacleTuples: [(Int, Int)],
        start: Position, end: Position,
        patrolDefs: [(cells: [(Int, Int)], kind: PatrolKind, phase: Int)]
    ) -> Level {
        let obstacles = Set(obstacleTuples.map { Position(row: $0.0, col: $0.1) })

        var cells: [GridCell] = []
        var lookup: [Position: GridCell] = [:]
        var id = 0
        for r in 0..<rows {
            for c in 0..<cols {
                let position = Position(row: r, col: c)
                let cell = GridCell(
                    id: id,
                    position: position,
                    isObstacle: obstacles.contains(position),
                    isStart: position == start,
                    isEnd: position == end
                )
                cells.append(cell)
                lookup[position] = cell
                id += 1
            }
        }

        let pirates: [Patrol] = patrolDefs.enumerated().map { index, def in
            let palette = pirateColorPalette[index % pirateColorPalette.count]
            return Patrol(
                id: index,
                name: palette.name,
                colorHex: palette.hex,
                cells: def.cells.map { Position(row: $0.0, col: $0.1) },
                kind: def.kind,
                phase: def.phase
            )
        }

        let optimalMoves = shortestPathLength(from: start, to: end, obstacles: obstacles, rows: rows, cols: cols)

        return Level(
            rows: rows, cols: cols, cells: cells, start: start, end: end,
            obstacles: obstacles, optimalMoves: max(1, optimalMoves),
            pirates: pirates, cellLookup: lookup
        )
    }

    // MARK: - Path planning (tap-to-plan, not tap-to-move)

    /// Invalid taps (obstacles, non-adjacent cells, out-of-grid via a
    /// stale view) are ignored rather than crashing.
    func tapTile(at position: Position) {
        guard phase == .planning else { return }
        guard let cell = currentLevel.cellLookup[position], !cell.isObstacle else { return }
        guard let last = currentPath.last else { return }

        // Tapping the cell just behind the head undoes that segment.
        if currentPath.count >= 2, position == currentPath[currentPath.count - 2] {
            currentPath.removeLast()
            return
        }

        guard isAdjacent(position, last), !currentPath.dropLast().contains(position) else { return }
        currentPath.append(position)
    }

    func undo() {
        guard canUndo else { return }
        currentPath.removeLast()
    }

    private func isAdjacent(_ a: Position, _ b: Position) -> Bool {
        abs(a.row - b.row) + abs(a.col - b.col) == 1
    }

    // MARK: - Hint (does not reveal until requested; costs the optimal-path bonus)

    private var hintWasUsed = false

    func requestHint() {
        guard phase == .planning else { return }
        hintWasUsed = true
        hintPath = computeSafePath(level: currentLevel, startTick: 0)
    }

    // MARK: - GO: simultaneous animated execution + collision detection

    func go() {
        guard canGo else { return }
        hintPath = nil
        phase = .executing
        executionTick = 0
        let path = currentPath
        let level = currentLevel!
        let attemptNumber = attempt
        let usedHintThisAttempt = hintWasUsed

        executionTask = Task { [weak self] in
            guard let self else { return }
            let tickNanos = UInt64(Self.tickDuration * 1_000_000_000)

            var priorPlayerPos = path[0]
            var priorPiratePositions = level.pirates.map { $0.position(atTick: 0) }

            for tick in 1..<path.count {
                try? await Task.sleep(nanoseconds: tickNanos)
                if Task.isCancelled { return }

                let playerPos = path[tick]
                let piratePositions = level.pirates.map { $0.position(atTick: tick) }

                self.executionTick = tick
                self.animatedShipPosition = playerPos
                self.animatedPiratePositions = piratePositions

                if let collision = Self.collidingPirate(
                    playerPrev: priorPlayerPos, playerCur: playerPos,
                    pirates: level.pirates, prevPositions: priorPiratePositions, curPositions: piratePositions
                ) {
                    let reason = collision.wasCrossing
                        ? "You and the \(collision.pirate.name) swapped places mid-move at row \(playerPos.row + 1), column \(playerPos.col + 1)."
                        : "You sailed straight into the \(collision.pirate.name) at row \(playerPos.row + 1), column \(playerPos.col + 1)."
                    self.finishLevel(
                        success: false,
                        movesUsed: tick,
                        attempt: attemptNumber,
                        collisionReason: reason,
                        usedHint: usedHintThisAttempt
                    )
                    return
                }

                priorPlayerPos = playerPos
                priorPiratePositions = piratePositions
            }

            self.finishLevel(
                success: true,
                movesUsed: path.count - 1,
                attempt: attemptNumber,
                collisionReason: nil,
                usedHint: usedHintThisAttempt
            )
        }
    }

    /// Checks both same-cell occupancy and "crossing" — the player and
    /// a pirate swapping cells within the same movement interval.
    /// Returns which pirate was hit, and whether it was a same-cell
    /// collision or a mid-move swap, so the failure message can be specific.
    private static func collidingPirate(
        playerPrev: Position, playerCur: Position,
        pirates: [Patrol], prevPositions: [Position], curPositions: [Position]
    ) -> (pirate: Patrol, wasCrossing: Bool)? {
        for (index, pirate) in pirates.enumerated() {
            let prev = prevPositions[index]
            let cur = curPositions[index]
            if cur == playerCur { return (pirate, false) }
            if playerCur == prev && playerPrev == cur { return (pirate, true) }
        }
        return nil
    }

    // MARK: - Scoring

    private func finishLevel(success: Bool, movesUsed: Int, attempt: Int, collisionReason: String?, usedHint: Bool) {
        executionTask?.cancel()

        let levelScore: Int
        let bonus: Int
        if success {
            let base = Self.basePointsPerLevel + (levelIndex * 20) // higher levels award more
            let isOptimal = !usedHint && movesUsed == currentLevel.optimalMoves
            bonus = isOptimal ? Self.optimalBonusPoints : 0
            let extraMoves = max(0, movesUsed - currentLevel.optimalMoves)
            let penalty = extraMoves * Self.penaltyPerExtraMove
            let multiplier = attempt <= 1 ? 1.0 : Self.secondAttemptMultiplier
            levelScore = max(0, Int((Double(base + bonus - penalty) * multiplier).rounded()))
        } else {
            bonus = 0
            levelScore = 0
        }

        totalScore += levelScore
        runningScore = totalScore

        let result = LevelResult(
            success: success,
            movesUsed: movesUsed,
            optimalMoves: currentLevel.optimalMoves,
            bonus: bonus,
            levelScore: levelScore,
            attempt: attempt,
            collisionReason: collisionReason,
            usedHint: usedHint
        )
        phase = .levelResult(result)
    }

    // MARK: - Retry / advance

    func retryLevel() {
        guard case .levelResult(let result) = phase, !result.success else { return }
        attempt = min(attempt + 1, 2)
        hintWasUsed = false
        currentPath = [currentLevel.start]
        hintPath = nil
        executionTick = 0
        animatedShipPosition = currentLevel.start
        animatedPiratePositions = currentLevel.pirates.map { $0.position(atTick: 0) }
        phase = .planning
    }

    func advanceToNextLevel() {
        guard case .levelResult(let result) = phase, result.success else { return }
        beginLevel(at: levelIndex + 1)
    }

    // MARK: - Game over

    private func endGame() {
        let score = max(0, totalScore)
        let duration: Int
        if let gameStartedAt {
            duration = max(1, Int(Date().timeIntervalSince(gameStartedAt).rounded()))
        } else {
            duration = Self.totalLevels * 10
        }

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Pirate Passage",
                category: "Problem Solving",
                score: score,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: score)
        }
    }

    // MARK: - Core algorithm: static BFS (scoring baseline)

    private static func shortestPathLength(from start: Position, to end: Position, obstacles: Set<Position>, rows: Int, cols: Int) -> Int {
        var visited: Set<Position> = [start]
        var queue: [(Position, Int)] = [(start, 0)]
        var head = 0
        while head < queue.count {
            let (pos, dist) = queue[head]; head += 1
            if pos == end { return dist }
            for n in neighbors(of: pos, rows: rows, cols: cols) where !obstacles.contains(n) && !visited.contains(n) {
                visited.insert(n)
                queue.append((n, dist + 1))
            }
        }
        return 0
    }

    // MARK: - Core algorithm: time-aware BFS for the Hint feature
    //
    // State is (row, col, time) exactly as specified: a cell is only
    // "safe" at the precise tick the player would arrive there, not
    // just wherever pirates happen to be right now.

    private func computeSafePath(level: Level, startTick: Int) -> [Position]? {
        let pirates = level.pirates
        guard !pirates.isEmpty else {
            return Self.staticPath(level: level)
        }

        let cycle = pirates.map { $0.period }.reduce(1) { Self.lcm($0, $1) }
        func piratePositions(_ tick: Int) -> [Position] { pirates.map { $0.position(atTick: tick) } }
        func collides(prevPlayer: Position, curPlayer: Position, prevP: [Position], curP: [Position]) -> Bool {
            if curP.contains(curPlayer) { return true }
            for (pp, cp) in zip(prevP, curP) where curPlayer == pp && prevPlayer == cp { return true }
            return false
        }

        if piratePositions(startTick).contains(level.start) { return nil }

        struct State: Hashable { let pos: Position; let tickMod: Int }

        var queue: [(Position, Int, [Position])] = [(level.start, startTick, [level.start])]
        var head = 0
        var seen: Set<State> = [State(pos: level.start, tickMod: startTick % cycle)]
        let maxTicks = startTick + level.rows * level.cols * 3 + 60

        while head < queue.count {
            let (pos, tick, path) = queue[head]; head += 1
            if pos == level.end { return path }
            if tick > maxTicks { continue }

            let curNow = piratePositions(tick)
            for n in Self.neighbors(of: pos, rows: level.rows, cols: level.cols) {
                guard let cell = level.cellLookup[n], !cell.isObstacle else { continue }
                let nTick = tick + 1
                let curNext = piratePositions(nTick)
                if collides(prevPlayer: pos, curPlayer: n, prevP: curNow, curP: curNext) { continue }
                let state = State(pos: n, tickMod: nTick % cycle)
                if seen.contains(state) { continue }
                seen.insert(state)
                queue.append((n, nTick, path + [n]))
            }
        }
        return nil
    }

    private static func staticPath(level: Level) -> [Position]? {
        var visited: Set<Position> = [level.start]
        var queue: [[Position]] = [[level.start]]
        var head = 0
        while head < queue.count {
            let path = queue[head]; head += 1
            guard let pos = path.last else { continue }
            if pos == level.end { return path }
            for n in neighbors(of: pos, rows: level.rows, cols: level.cols) {
                guard let cell = level.cellLookup[n], !cell.isObstacle, !visited.contains(n) else { continue }
                visited.insert(n)
                queue.append(path + [n])
            }
        }
        return nil
    }

    private static func neighbors(of p: Position, rows: Int, cols: Int) -> [Position] {
        [(-1, 0), (1, 0), (0, -1), (0, 1)].compactMap { dr, dc in
            let np = Position(row: p.row + dr, col: p.col + dc)
            guard np.row >= 0, np.row < rows, np.col >= 0, np.col < cols else { return nil }
            return np
        }
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a, b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    private static func lcm(_ a: Int, _ b: Int) -> Int {
        a / gcd(a, b) * b
    }
}