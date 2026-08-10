//
//  RootView.swift
//  LumiMind
//

import SwiftUI

enum RootDestination {
    case splash
    case welcome
    case onboardingQuestionnaire
    case socialProof
    case signup
    case login
    case fitTestIntro
    case memoryMatrixFitTest
    case resultsPlan
    case difficultySelection
    case streakConfirmation
    case main
}

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var destination: RootDestination = .splash

    // Carried across onboarding steps
    @State private var onboardingGoals: [String] = []
    @State private var onboardingDifficultyPlaceholder: String = "Beginner"
    @State private var fitTestScore: Int?
    @State private var fitTestDuration: Int?
    @StateObject private var fitTestResultViewModel = GameResultViewModel()

    var body: some View {
        Group {
            switch destination {
            case .splash:
                SplashView(authViewModel: authViewModel) {
                    destination = authViewModel.isAuthenticated ? .main : .welcome
                }
            case .welcome:
                WelcomeView(
                    onGetStarted: { destination = .onboardingQuestionnaire }
                )
            case .onboardingQuestionnaire:
                QuestionnaireFlowView(
                    onComplete: { answers in
                        onboardingGoals = Array(answers["goals"] ?? [])
                        // TODO: DifficultySelectionView (backlog #13) is the
                        // real place difficultyLevel is picked. SignupView
                        // requires a value immediately, so we seed a
                        // placeholder here and let DifficultySelectionView
                        // overwrite it later via submitOnboarding.
                        destination = .socialProof
                    },
                    onCancel: { destination = .welcome }
                )
            case .socialProof:
                SocialProofView(onContinue: { destination = .signup })
            case .signup:
                SignupView(
                    authViewModel: authViewModel,
                    goals: onboardingGoals,
                    difficultyLevel: onboardingDifficultyPlaceholder,
                    onSignupComplete: { destination = .fitTestIntro },
                    onCancel: { destination = .socialProof }
                )
            case .login:
                LoginView(
                    authViewModel: authViewModel,
                    onLoginSuccess: { destination = .main },
                    onCancel: { destination = .welcome }
                )
            case .fitTestIntro:
                FitTestIntroView(onStart: {
                    destination = .memoryMatrixFitTest
                })
            case .memoryMatrixFitTest:
                MemoryMatrixView(
                    gameResultViewModel: fitTestResultViewModel,
                    isFitTest: true,
                    onComplete: {
                        fitTestScore = fitTestResultViewModel.results.first?.score
                        fitTestDuration = fitTestResultViewModel.results.first?.durationSeconds
                        destination = .resultsPlan
                    }
                )
            case .resultsPlan:
                ResultsPlanView(
                    score: fitTestScore,
                    durationSeconds: fitTestDuration,
                    onContinue: { destination = .difficultySelection }
                )
            case .difficultySelection:
                DifficultySelectionView(
                    authViewModel: authViewModel,
                    onContinue: { destination = .streakConfirmation }
                )
            case .streakConfirmation:
                StreakConfirmationView(
                    authViewModel: authViewModel,
                    onFinishOnboarding: { destination = .main }
                )
            case .main:
                MainTabView(authViewModel: authViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: destination)
        .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
            if !isAuthenticated && destination == .main {
                destination = .welcome
            }
        }
    }
}

#Preview {
    RootView()
}