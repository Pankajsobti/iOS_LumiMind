//
//  RootView.swift
//  LumiMind
//
//  Owns the app's top-level navigation state.
//
//  NOTE ON PLACEHOLDERS: `OnboardingQuestionnaireView` (build prompt #8),
//  `LoginView` (build prompt #10), and `MainTabView` don't exist yet.
//  The `*PlaceholderView`s below stand in for them so this file compiles
//  and routes correctly today. When those screens are built, swap the
//  matching placeholder case below for the real view — nothing else in
//  RootView needs to change.
//

import SwiftUI

enum RootDestination {
    case splash
    case welcome
    case onboardingQuestionnaire
    case login
    case main
}

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var destination: RootDestination = .splash

    var body: some View {
        Group {
            switch destination {
            case .splash:
                SplashView(authViewModel: authViewModel) {
                    destination = authViewModel.isAuthenticated ? .main : .welcome
                }
            case .welcome:
                WelcomeView(
                    onGetStarted: { destination = .onboardingQuestionnaire },
                    onLogIn: { destination = .login }
                )
            case .onboardingQuestionnaire:
                OnboardingQuestionnairePlaceholderView()
            case .login:
                LoginPlaceholderView()
            case .main:
                MainAppPlaceholderView()
            }
        }
    }
}

// MARK: - Temporary placeholders (remove once the real screens exist)

private struct OnboardingQuestionnairePlaceholderView: View {
    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding.ignoresSafeArea()
            Text("Onboarding Questionnaire")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundMain)
        }
    }
}

private struct LoginPlaceholderView: View {
    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding.ignoresSafeArea()
            Text("Login")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundMain)
        }
    }
}

private struct MainAppPlaceholderView: View {
    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()
            Text("Main App — Today")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
    }
}

#Preview {
    RootView()
}