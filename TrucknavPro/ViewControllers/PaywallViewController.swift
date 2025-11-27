//
//  PaywallViewController.swift
//  TruckNavPro
//

import UIKit
import RevenueCat

class PaywallViewController: UIViewController {

    var requiredFeature: Feature?
    var onComplete: (() -> Void)?
    private var products: [StoreProduct] = []
    private var loadRetryCount = 0
    private let maxRetries = 3

    // Product ID from App Store Connect
    private let productIDs = ["pro_monthly1"]

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let packageStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let restoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Restore Purchases", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let termsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Terms & Privacy", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        button.setTitleColor(.tertiaryLabel, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading subscription options..."
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadProducts()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(closeButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(loadingIndicator)
        contentView.addSubview(loadingLabel)
        contentView.addSubview(packageStackView)
        contentView.addSubview(restoreButton)
        contentView.addSubview(termsButton)

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        termsButton.addTarget(self, action: #selector(termsTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            closeButton.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            loadingIndicator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 60),
            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            packageStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            packageStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            packageStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            restoreButton.topAnchor.constraint(equalTo: packageStackView.bottomAnchor, constant: 32),
            restoreButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            termsButton.topAnchor.constraint(equalTo: restoreButton.bottomAnchor, constant: 16),
            termsButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            termsButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])

        // Set content based on required feature
        if let feature = requiredFeature {
            titleLabel.text = "Unlock \(feature.displayName)"
            subtitleLabel.text = "Subscribe to access this feature"
        } else {
            titleLabel.text = "TruckNav Pro"
            subtitleLabel.text = "Unlimited truck navigation, HOS tracking, expense tracking & more"
        }
    }

    // MARK: - Load Products

    private func loadProducts() {
        print("🔄 Starting to load products from App Store (attempt \(loadRetryCount + 1)/\(maxRetries))...")
        print("📦 Requesting product IDs: \(productIDs)")

        // Show loading indicator
        loadingIndicator.startAnimating()
        loadingLabel.isHidden = false
        packageStackView.isHidden = true

        // Check if RevenueCat is configured
        guard RevenueCatService.shared.isConfigured else {
            print("❌ RevenueCat is not configured - showing fallback")
            hideLoading()
            displayFallbackPackages()
            return
        }

        Task {
            do {
                // Fetch products directly by ID from App Store
                let fetchedProducts = try await Purchases.shared.products(productIDs)
                print("✅ Products loaded successfully: \(fetchedProducts.count)")

                for product in fetchedProducts {
                    print("📦 Product: \(product.productIdentifier) - \(product.localizedTitle) - \(product.localizedPriceString)")
                }

                await MainActor.run {
                    loadRetryCount = 0 // Reset on success
                    products = fetchedProducts
                    hideLoading()
                    displayProducts()
                }
            } catch {
                print("❌ Error loading products: \(error)")
                print("❌ Error details: \(error.localizedDescription)")

                await MainActor.run {
                    // Retry with exponential backoff
                    if loadRetryCount < maxRetries {
                        loadRetryCount += 1
                        let delay = Double(loadRetryCount) * 1.5 // 1.5s, 3s, 4.5s
                        print("🔄 Retrying in \(delay) seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                            self?.loadProducts()
                        }
                    } else {
                        print("❌ Max retries reached - showing fallback")
                        hideLoading()
                        displayFallbackPackages()
                    }
                }
            }
        }
    }

    private func displayProducts() {
        print("📱 displayProducts() called")

        // Clear existing views
        packageStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !products.isEmpty else {
            print("❌ No products available - showing fallback")
            displayFallbackPackages()
            return
        }

        // Sort products by price (cheapest first)
        let sortedProducts = products.sorted { $0.price < $1.price }

        for product in sortedProducts {
            let productView = createProductView(for: product)
            packageStackView.addArrangedSubview(productView)
        }

        print("✅ Displayed \(sortedProducts.count) products")
    }

    private func createProductView(for product: StoreProduct) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.layer.cornerCurve = .continuous

        let nameLabel = UILabel()
        nameLabel.text = "TruckNav Pro"
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Add subscription period/length
        let periodLabel = UILabel()
        periodLabel.text = "Monthly - Full Access"
        periodLabel.font = .systemFont(ofSize: 18, weight: .medium)
        periodLabel.textColor = .label
        periodLabel.translatesAutoresizingMaskIntoConstraints = false

        let priceLabel = UILabel()
        priceLabel.text = "$9.99/month"
        priceLabel.font = .systemFont(ofSize: 24, weight: .bold)
        priceLabel.textColor = .systemBlue
        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        // Remove savings label - no yearly plan
        let savingsLabel = UILabel()
        savingsLabel.text = ""
        savingsLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.text = "• Full access truck navigation\n• Weather\n• Traffic alerts"
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        let subscribeButton = UIButton(type: .system)
        subscribeButton.setTitle("Subscribe", for: .normal)
        subscribeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        subscribeButton.backgroundColor = .systemBlue
        subscribeButton.setTitleColor(.white, for: .normal)
        subscribeButton.layer.cornerRadius = 12
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        subscribeButton.addTarget(self, action: #selector(productSubscribeTapped(_:)), for: .touchUpInside)

        // Store product reference
        objc_setAssociatedObject(subscribeButton, &productKey, product, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        container.addSubview(nameLabel)
        container.addSubview(periodLabel)
        container.addSubview(priceLabel)
        container.addSubview(savingsLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(subscribeButton)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            periodLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            periodLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            periodLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            priceLabel.topAnchor.constraint(equalTo: periodLabel.bottomAnchor, constant: 8),
            priceLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            priceLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            savingsLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 4),
            savingsLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            savingsLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            descriptionLabel.topAnchor.constraint(equalTo: savingsLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            subscribeButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            subscribeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subscribeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            subscribeButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            subscribeButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        return container
    }

    @objc private func productSubscribeTapped(_ sender: UIButton) {
        guard let product = objc_getAssociatedObject(sender, &productKey) as? StoreProduct else {
            return
        }

        sender.isEnabled = false
        sender.setTitle("Processing...", for: .normal)

        Task {
            do {
                let result = try await Purchases.shared.purchase(product: product)
                if !result.userCancelled {
                    await MainActor.run {
                        // Dismiss immediately - go straight back to app
                        dismiss(animated: true) {
                            self.onComplete?()
                        }
                    }
                } else {
                    await MainActor.run {
                        sender.isEnabled = true
                        sender.setTitle("Subscribe", for: .normal)
                    }
                }
            } catch {
                await MainActor.run {
                    // Better error handling for sandbox/production issues
                    let errorMessage: String
                    if let purchaseError = error as? ErrorCode {
                        switch purchaseError {
                        case .receiptAlreadyInUseError:
                            errorMessage = "This subscription is already active on another account."
                        case .invalidReceiptError:
                            errorMessage = "Unable to verify purchase. Please try again or contact support."
                        case .missingReceiptFileError:
                            errorMessage = "Purchase verification failed. Please restore purchases."
                        case .networkError:
                            errorMessage = "Network error. Please check your connection."
                        case .purchaseCancelledError:
                            // User cancelled - don't show error
                            sender.isEnabled = true
                            sender.setTitle("Subscribe", for: .normal)
                            return
                        default:
                            errorMessage = "Purchase failed. Please try again. Error: \(purchaseError.localizedDescription)"
                        }
                    } else {
                        errorMessage = "Purchase failed. Please try again or contact support."
                    }

                    showError(errorMessage)
                    sender.isEnabled = true
                    sender.setTitle("Subscribe", for: .normal)
                }
            }
        }
    }

    // MARK: - Fallback Packages (for when products can't be loaded)

    private func displayFallbackPackages() {
        print("📱 Displaying fallback packages for Apple Review")

        // Clear existing package views
        packageStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Hardcoded fallback subscription - shown when RevenueCat fails
        let fallbackPlans = [
            ("TruckNav Pro", "$9.99/month", "Full access to all premium features")
        ]

        for plan in fallbackPlans {
            let packageView = createFallbackPackageView(
                name: plan.0,
                price: plan.1,
                description: plan.2
            )
            packageStackView.addArrangedSubview(packageView)
        }

        print("✅ Displayed \(fallbackPlans.count) fallback packages")
    }

    private func createFallbackPackageView(name: String, price: String, description: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.layer.cornerCurve = .continuous

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let priceLabel = UILabel()
        priceLabel.text = price
        priceLabel.font = .systemFont(ofSize: 28, weight: .bold)
        priceLabel.textColor = .systemBlue
        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        let subscribeButton = UIButton(type: .system)
        subscribeButton.setTitle("Subscribe", for: .normal)
        subscribeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        subscribeButton.backgroundColor = .systemBlue
        subscribeButton.setTitleColor(.white, for: .normal)
        subscribeButton.layer.cornerRadius = 12
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        subscribeButton.addTarget(self, action: #selector(fallbackSubscribeTapped), for: .touchUpInside)

        container.addSubview(nameLabel)
        container.addSubview(priceLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(subscribeButton)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 12),
            priceLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            priceLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            descriptionLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            subscribeButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            subscribeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subscribeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            subscribeButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            subscribeButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        return container
    }

    @objc private func fallbackSubscribeTapped() {
        // Show user-friendly error when subscriptions can't be loaded
        print("⚠️ Fallback subscribe tapped - showing connection error")

        let alert = UIAlertController(
            title: "Unable to Connect",
            message: "We couldn't connect to the App Store. Please check your internet connection and try again.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            // Attempt to reload products
            self?.loadProducts()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true) {
                self?.onComplete?()
            }
        })

        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true) {
            self.onComplete?()
        }
    }

    @objc private func restoreTapped() {
        // Check if RevenueCat is configured
        guard RevenueCatService.shared.isConfigured else {
            showError("Subscription features are currently unavailable.\n\nPlease contact support if this issue persists.")
            return
        }

        restoreButton.isEnabled = false
        restoreButton.setTitle("Restoring...", for: .normal)

        Task {
            do {
                _ = try await RevenueCatService.shared.restorePurchases()
                await MainActor.run {
                    showSuccess("Purchases restored!")
                    dismiss(animated: true) {
                        self.onComplete?()
                    }
                }
            } catch {
                await MainActor.run {
                    showError("Restore failed: \(error.localizedDescription)")
                    restoreButton.isEnabled = true
                    restoreButton.setTitle("Restore Purchases", for: .normal)
                }
            }
        }
    }

    @objc private func termsTapped() {
        // Show action sheet with options for Terms, Privacy, and EULA
        let alert = UIAlertController(title: "Legal", message: "Choose a document to view", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Terms of Service", style: .default) { _ in
            // Apple's standard terms
            if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "Privacy Policy", style: .default) { _ in
            // Apple's privacy policy
            if let url = URL(string: "https://www.apple.com/privacy/") {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "EULA", style: .default) { _ in
            // Apple's standard EULA
            if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad popover configuration to prevent crash
        if let popover = alert.popoverPresentationController {
            popover.sourceView = termsButton
            popover.sourceRect = termsButton.bounds
        }

        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func hideLoading() {
        loadingIndicator.stopAnimating()
        loadingLabel.isHidden = true
        packageStackView.isHidden = false
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSuccess(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// Associated object keys for storing references
private var packageKey: UInt8 = 0
private var productKey: UInt8 = 0
