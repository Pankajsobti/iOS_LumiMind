//
//  AuthViewModel.swift
//  LumiMind
//
//  Owns auth/session state for the app. Every screen that needs to
//  know "who is logged in" or trigger signup/login/logout should read
//  from / call into this ViewModel rather than talking to APIClient
//  or KeychainManager directly.
//

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient
    private let keychain: KeychainManager

   init(apiClient: APIClient? = nil, keychain: KeychainManager? = nil) {
    self.apiClient = apiClient ?? .shared
    self.keychain = keychain ?? .shared
    // A stored token means a previous session exists; callers should
    // still call `fetchCurrentUser()` on launch to hydrate `currentUser`
    // (and to discover a stale/expired token, which flips this back off).
    self.isAuthenticated = (self.keychain).getToken() != nil
}

    // MARK: - Signup / Login

    func signup(email: String, password: String) async {
        await performAuthRequest(endpoint: .signup, email: email, password: password)
    }

    func login(email: String, password: String) async {
        await performAuthRequest(endpoint: .login, email: email, password: password)
    }

    private func performAuthRequest(endpoint: Endpoint, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let body = AuthRequest(email: email, password: password)
            let response: AuthResponse = try await apiClient.request(
                endpoint: endpoint,
                method: .post,
                body: body,
                requiresAuth: false
            )
            keychain.saveToken(response.token)
            currentUser = response.user
            isAuthenticated = true
        } catch {
            errorMessage = Self.message(for: error)
            isAuthenticated = false
        }
    }

    // MARK: - Logout

    /// Clears both Keychain and in-memory session state.
    func logout() {
        keychain.deleteToken()
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }

    // MARK: - Onboarding

    func submitOnboarding(goals: [String], difficultyLevel: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let body = OnboardingRequest(goals: goals, difficultyLevel: difficultyLevel)
            let user: User = try await apiClient.request(
                endpoint: .onboarding,
                method: .patch,
                body: body,
                requiresAuth: true
            )
            currentUser = user
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Fetch current user

    func fetchCurrentUser() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user: User = try await apiClient.request(
                endpoint: .me,
                method: .get,
                requiresAuth: true
            )
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = Self.message(for: error)
            // A 401 here means the stored token is invalid/expired —
            // treat the session as over rather than leaving stale state.
            if let apiError = error as? APIClientError, apiError.statusCode == 401 {
                logout()
            }
        }
    }

    // MARK: - Error mapping

    private static func message(for error: Error) -> String {
        (error as? APIClientError)?.errorDescription ?? error.localizedDescription
    }
}