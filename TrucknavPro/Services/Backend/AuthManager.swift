//
//  AuthManager.swift
//  TruckNavPro
//
//  Manages authentication state and session persistence

import Foundation
import Supabase
import Combine

@MainActor
class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true

    private var cancellables = Set<AnyCancellable>()

    private init() {
        Task {
            await checkAuthenticationStatus()
        }
    }

    // MARK: - Authentication Check

    func checkAuthenticationStatus() async {
        isLoading = true

        do {
            let session = try await SupabaseService.shared.getCurrentSession()
            currentUser = session.user
            isAuthenticated = true
            print("✅ User is authenticated: \(session.user.email ?? "unknown")")
        } catch {
            currentUser = nil
            isAuthenticated = false
            print("ℹ️ No active session - user needs to sign in")
        }

        isLoading = false
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        let session = try await SupabaseService.shared.signIn(email: email, password: password)
        currentUser = session.user
        isAuthenticated = true
        print("✅ Sign in successful: \(email)")
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async throws {
        let user = try await SupabaseService.shared.signUp(email: email, password: password)

        // After sign up, sign in automatically
        let session = try await SupabaseService.shared.signIn(email: email, password: password)
        currentUser = session.user
        isAuthenticated = true
        print("✅ Sign up successful: \(email)")
    }

    // MARK: - Sign In with Apple

    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
        currentUser = session.user
        isAuthenticated = true
        print("✅ Sign in with Apple successful")
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await SupabaseService.shared.signOut()
        currentUser = nil
        isAuthenticated = false
        print("✅ Sign out successful")
    }

    // MARK: - User Profile

    func getUserEmail() -> String? {
        return currentUser?.email
    }

    func getUserId() -> String? {
        return currentUser?.id.uuidString
    }
}
