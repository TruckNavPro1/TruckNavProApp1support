//
//  AppleSignInButton_Supabase.swift
//  TruckNavPro
//

import SwiftUI
import AuthenticationServices
import Supabase

struct AppleSignInButton_Supabase: View {
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        SignInWithAppleButton(.signIn) { req in
            req.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                guard
                    let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = cred.identityToken,
                    let idToken = String(data: tokenData, encoding: .utf8)
                else {
                    print("❌ Missing Apple identity token")
                    showErrorAlert("Failed to get Apple credentials. Please try again.")
                    return
                }
                Task { @MainActor in
                    do {
                        let session = try await SupabaseService.shared.client.auth.signInWithIdToken(
                            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken)
                        )
                        // Update AuthManager state
                        AuthManager.shared.currentUser = session.user
                        AuthManager.shared.isAuthenticated = true
                        print("✅ Apple sign-in via Supabase complete")
                    } catch {
                        print("❌ Supabase Apple sign-in failed: \(error)")
                        showErrorAlert("Sign in failed: \(error.localizedDescription)")
                    }
                }
            case .failure(let err):
                print("❌ Apple Sign-In error:", err)
                // Don't show alert for user cancellation
                if (err as NSError).code != 1001 {
                    showErrorAlert("Apple Sign-In failed. Please try again.")
                }
            }
        }
        .signInWithAppleButtonStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6, y: 3)
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}
