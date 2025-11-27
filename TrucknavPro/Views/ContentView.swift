//
//  ContentView.swift
//  TruckNavPro
//

import SwiftUI

struct ContentView: View {

    @StateObject private var authManager = AuthManager.shared
    @State private var hasActiveSubscription = false
    @State private var isCheckingSubscription = true
    @State private var hasPassedPaywall = false

    var body: some View {
        Group {
            if authManager.isLoading || isCheckingSubscription {
                // Loading screen
                LoadingView()
            } else if authManager.isAuthenticated {
                if hasActiveSubscription || hasPassedPaywall {
                    // Has subscription OR passed paywall - go to app
                    NavigationViewControllerRepresentable()
                        .ignoresSafeArea()
                } else {
                    // No subscription - MUST see paywall
                    WelcomeViewControllerRepresentable(onComplete: {
                        // User closed paywall (with X or purchase)
                        hasPassedPaywall = true
                    })
                    .ignoresSafeArea()
                }
            } else {
                // Login screen - authentication REQUIRED - TRON EDITION
                LaunchView_Tron()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            checkSubscription()
        }
    }

    private func checkSubscription() {
        Task {
            do {
                _ = try await RevenueCatService.shared.getCustomerInfo()
                let isPro = RevenueCatService.shared.currentTier.isPro
                await MainActor.run {
                    hasActiveSubscription = isPro
                    isCheckingSubscription = false
                }
            } catch {
                await MainActor.run {
                    hasActiveSubscription = false
                    isCheckingSubscription = false
                }
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("TruckNav Pro")
                    .font(.system(size: 28, weight: .bold))

                ProgressView()
                    .scaleEffect(x: 1.5, y: 1.5)
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Welcome Representable

struct WelcomeViewControllerRepresentable: UIViewControllerRepresentable {

    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> WelcomeViewController {
        let welcomeVC = WelcomeViewController()

        welcomeVC.onGetStarted = {
            onComplete()
        }

        return welcomeVC
    }

    func updateUIViewController(_ uiViewController: WelcomeViewController, context: Context) {
    }
}

// MARK: - Navigation Representable

struct NavigationViewControllerRepresentable: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UINavigationController {
        let mapViewController = MapViewController()
        let navController = UINavigationController(rootViewController: mapViewController)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
}

#Preview {
    ContentView()
}
