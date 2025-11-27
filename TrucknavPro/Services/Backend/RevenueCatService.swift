//
//  RevenueCatService.swift
//  TruckNavPro
//

import Foundation
import RevenueCat
import StoreKit
import UIKit

// MARK: - Subscription Tiers

enum SubscriptionTier: String {
    case free = "free"
    case proWeekly = "pro_weekly1"
    case proMonthly = "pro_monthly1"
    case premium = "pro_yearly1"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .proWeekly: return "Pro Weekly"
        case .proMonthly: return "Pro Monthly"
        case .premium: return "Premium Yearly"
        }
    }

    var isPro: Bool {
        return self == .proWeekly || self == .proMonthly || self == .premium
    }

    var isPremium: Bool {
        return self == .premium
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "Basic navigation",
                "TomTom truck routing",
                "Weather widget",
                "Up to 5 saved routes"
            ]
        case .proWeekly, .proMonthly:
            return [
                "All Free features",
                "Unlimited saved routes",
                "Offline maps",
                "Advanced truck settings",
                "Traffic alerts",
                "Trip history (30 days)"
            ]
        case .premium:
            return [
                "All Pro features",
                "Lifetime trip history",
                "Priority support",
                "Custom truck profiles",
                "Fleet management tools",
                "Ad-free experience"
            ]
        }
    }
}

// MARK: - RevenueCat Service

class RevenueCatService {

    static let shared = RevenueCatService()

    // Track if RevenueCat was successfully configured
    private(set) var isConfigured: Bool = false

    // Current subscription tier
    private(set) var currentTier: SubscriptionTier = .free

    // Active entitlements
    private(set) var activeEntitlements: Set<String> = []

    private init() {
        configure()
    }

    // MARK: - Configuration

    func configure() {
        // Load RevenueCat API key from Info.plist
        guard let apiKey = Bundle.main.infoDictionary?["RevenueCatAPIKey"] as? String else {
            print("⚠️ RevenueCat API key not found in Info.plist")
            print("⚠️ RevenueCat will NOT be configured - subscription features unavailable")
            isConfigured = false
            return
        }

        // Configure with API key
        // Note: Purchases.logLevel is set to .error in TrucknavProApp.swift init
        // RevenueCat SDK automatically handles sandbox vs production receipt validation
        Purchases.configure(withAPIKey: apiKey)

        // Enable automatic sandbox detection for App Review
        // This ensures the SDK properly handles both sandbox and production receipts
        #if DEBUG
        print("🔧 RevenueCat running in DEBUG mode (sandbox)")
        #else
        print("🔧 RevenueCat running in RELEASE mode (production)")
        // RevenueCat automatically detects and handles sandbox receipts in production builds
        // This is critical for App Store review process
        #endif

        isConfigured = true

        // Set user ID if logged in
        Task {
            if let userId = await SupabaseService.shared.currentUser?.id.uuidString {
                Purchases.shared.logIn(userId) { customerInfo, created, error in
                    if let error = error {
                        print("❌ RevenueCat login error: \(error.localizedDescription)")
                        // Don't block app if login fails - user can still access free features
                        self.updateSubscriptionStatus(customerInfo: nil)
                    } else {
                        print("✅ RevenueCat user logged in: \(userId)")
                        self.updateSubscriptionStatus(customerInfo: customerInfo)
                    }
                }
            } else {
                // No user logged in - fetch customer info anonymously
                Task { @MainActor in
                    do {
                        let customerInfo = try await self.getCustomerInfo()
                        print("✅ RevenueCat configured with anonymous user")
                    } catch {
                        print("⚠️ RevenueCat customer info fetch failed: \(error.localizedDescription)")
                        // Don't block app - user can still access free features
                        self.updateSubscriptionStatus(customerInfo: nil)
                    }
                }
            }
        }

        print("✅ RevenueCat configured")
    }

    // MARK: - Subscription Management

    /// Get available packages/offerings
    func getOfferings() async throws -> Offerings {
        guard isConfigured else {
            throw RevenueCatError.notConfigured
        }
        return try await Purchases.shared.offerings()
    }

    /// Purchase a package
    func purchase(package: Package) async throws -> (transaction: StoreTransaction?, customerInfo: CustomerInfo, userCancelled: Bool) {
        guard isConfigured else {
            throw RevenueCatError.notConfigured
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            updateSubscriptionStatus(customerInfo: result.customerInfo)
            print("✅ Purchase successful: \(package.storeProduct.localizedTitle)")
            return result
        } catch let error as ErrorCode {
            // Handle specific RevenueCat errors
            switch error {
            case .receiptAlreadyInUseError:
                print("⚠️ Receipt already in use - restoring purchases")
                // Attempt to restore purchases to sync subscription status
                let customerInfo = try await Purchases.shared.restorePurchases()
                updateSubscriptionStatus(customerInfo: customerInfo)
                throw RevenueCatError.receiptInUse
            case .invalidReceiptError, .missingReceiptFileError:
                print("❌ Invalid or missing receipt - attempting refresh")
                // Let RevenueCat handle receipt refresh automatically
                throw RevenueCatError.receiptInvalid
            case .networkError:
                print("❌ Network error during purchase")
                throw RevenueCatError.networkError
            default:
                print("❌ Purchase error: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Restore purchases
    func restorePurchases() async throws -> CustomerInfo {
        guard isConfigured else {
            throw RevenueCatError.notConfigured
        }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateSubscriptionStatus(customerInfo: customerInfo)
            print("✅ Purchases restored")
            return customerInfo
        } catch let error as ErrorCode {
            // Handle receipt validation errors gracefully
            switch error {
            case .invalidReceiptError, .missingReceiptFileError:
                print("⚠️ Receipt validation issue during restore - user may have no purchases")
                // Return empty customer info instead of crashing
                updateSubscriptionStatus(customerInfo: nil)
                throw RevenueCatError.receiptInvalid
            case .networkError:
                print("❌ Network error during restore")
                throw RevenueCatError.networkError
            default:
                print("❌ Restore error: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Get current customer info
    func getCustomerInfo() async throws -> CustomerInfo {
        guard isConfigured else {
            throw RevenueCatError.notConfigured
        }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateSubscriptionStatus(customerInfo: customerInfo)
            return customerInfo
        } catch let error as ErrorCode {
            // Handle receipt validation errors gracefully
            switch error {
            case .invalidReceiptError, .missingReceiptFileError:
                print("⚠️ Receipt validation issue - treating as free user")
                // Treat as free user instead of blocking app
                updateSubscriptionStatus(customerInfo: nil)
                throw RevenueCatError.receiptInvalid
            case .networkError:
                print("⚠️ Network error fetching customer info - using cached status")
                throw RevenueCatError.networkError
            default:
                print("❌ Customer info error: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Update subscription status based on customer info
    private func updateSubscriptionStatus(customerInfo: CustomerInfo?) {
        guard let info = customerInfo else {
            currentTier = .free
            activeEntitlements = []
            return
        }

        // Update active entitlements
        activeEntitlements = Set(info.entitlements.active.keys)

        // Determine current tier (check premium first, then pro tiers)
        if info.entitlements.active["premium"] != nil || info.entitlements.active["pro_yearly"] != nil {
            currentTier = .premium
        } else if info.entitlements.active["pro_monthly"] != nil {
            currentTier = .proMonthly
        } else if info.entitlements.active["pro_weekly"] != nil {
            currentTier = .proWeekly
        } else if info.entitlements.active["pro"] != nil {
            // Fallback for legacy "pro" entitlement
            currentTier = .proMonthly
        } else {
            currentTier = .free
        }

        print("📱 Subscription updated: \(currentTier.displayName)")
        print("🎟️ Active entitlements: \(activeEntitlements)")

        // Post notification for UI updates
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }

    // MARK: - Feature Gating

    /// Check if user has access to a specific feature
    func hasAccess(to feature: Feature) -> Bool {
        switch feature {
        case .basicNavigation, .weather, .search:
            return true  // Available to all

        case .unlimitedRoutes, .offlineMaps, .advancedTruckSettings, .trafficAlerts:
            return currentTier.isPro  // All Pro and Premium tiers

        case .lifetimeHistory, .prioritySupport, .customProfiles, .fleetManagement:
            return currentTier.isPremium  // Premium only
        }
    }

    /// Show paywall if feature is locked
    func checkFeatureAccess(feature: Feature, from viewController: UIViewController) -> Bool {
        if hasAccess(to: feature) {
            return true
        } else {
            showPaywall(from: viewController, feature: feature)
            return false
        }
    }

    /// Present paywall
    func showPaywall(from viewController: UIViewController, feature: Feature? = nil) {
        let paywallVC = PaywallViewController()
        paywallVC.requiredFeature = feature
        paywallVC.modalPresentationStyle = .fullScreen
        viewController.present(paywallVC, animated: true)
    }
}

// MARK: - Features

enum Feature {
    // Free tier
    case basicNavigation
    case weather
    case search

    // Pro tier
    case unlimitedRoutes
    case offlineMaps
    case advancedTruckSettings
    case trafficAlerts

    // Premium tier
    case lifetimeHistory
    case prioritySupport
    case customProfiles
    case fleetManagement

    var displayName: String {
        switch self {
        case .basicNavigation: return "Basic Navigation"
        case .weather: return "Weather Widget"
        case .search: return "Search"
        case .unlimitedRoutes: return "Unlimited Saved Routes"
        case .offlineMaps: return "Offline Maps"
        case .advancedTruckSettings: return "Advanced Truck Settings"
        case .trafficAlerts: return "Traffic Alerts"
        case .lifetimeHistory: return "Lifetime Trip History"
        case .prioritySupport: return "Priority Support"
        case .customProfiles: return "Custom Truck Profiles"
        case .fleetManagement: return "Fleet Management"
        }
    }

    var requiredTier: SubscriptionTier {
        switch self {
        case .basicNavigation, .weather, .search:
            return .free
        case .unlimitedRoutes, .offlineMaps, .advancedTruckSettings, .trafficAlerts:
            return .proWeekly  // Any Pro tier will work
        case .lifetimeHistory, .prioritySupport, .customProfiles, .fleetManagement:
            return .premium
        }
    }
}

// MARK: - RevenueCat Errors

enum RevenueCatError: LocalizedError {
    case notConfigured
    case receiptInUse
    case receiptInvalid
    case networkError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "RevenueCat is not configured. Please check your setup."
        case .receiptInUse:
            return "This purchase is already associated with another account."
        case .receiptInvalid:
            return "Unable to validate your purchase. Please try again later."
        case .networkError:
            return "Network connection error. Please check your internet connection."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
