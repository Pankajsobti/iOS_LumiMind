//
//  MyBrainViewModel.swift
//  LumiMind
//
//  Orchestrates the "My Brain" tab's data loading. Does NOT own or
//  duplicate any published state — `GameResultViewModel` (the shared
//  instance owned by `MainTabView`) remains the single source of truth
//  for `stats` and `results`. This ViewModel's only job is to trigger
//  the two fetches this screen needs together and track whether the
//  first load has completed, so the view can tell "still loading"
//  apart from "loaded, genuinely empty" for new users.
//

import Foundation
import Combine

@MainActor
final class MyBrainViewModel: ObservableObject {

    /// How many history entries this screen requests. Kept here as the
    /// one place this screen's fetch parameters are decided.
    static let historyLimit = 20

    @Published private(set) var hasLoadedOnce = false

    private let gameResultViewModel: GameResultViewModel

    init(gameResultViewModel: GameResultViewModel) {
        self.gameResultViewModel = gameResultViewModel
    }

    /// Called from the view's `.task`/`.refreshable`. Fetches stats and
    /// history concurrently via `GameResultViewModel`'s existing
    /// methods — reuses its fetch/error-handling logic rather than
    /// re-implementing networking here.
    func load() async {
        async let statsFetch: Void = gameResultViewModel.fetchStats()
        async let resultsFetch: Void = gameResultViewModel.fetchResults(category: nil, limit: Self.historyLimit)
        _ = await (statsFetch, resultsFetch)
        hasLoadedOnce = true
    }
}