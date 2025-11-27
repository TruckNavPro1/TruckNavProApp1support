//
//  WelcomeViewController.swift
//  TruckNavPro
//
//  Welcome screen shown after user authentication

import UIKit

class WelcomeViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to\nTruckNav Pro!"
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 40, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let featuresStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let getStartedButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Get Started", for: .normal)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Properties

    var onGetStarted: (() -> Void)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadUserInfo()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(welcomeLabel)
        contentView.addSubview(emailLabel)
        contentView.addSubview(featuresStackView)
        contentView.addSubview(getStartedButton)

        // Add features
        addFeature(
            icon: "map.fill",
            title: "Smart Truck Routing",
            description: "Get routes optimized for your truck's height, weight, and hazmat restrictions"
        )

        addFeature(
            icon: "location.fill.viewfinder",
            title: "Real-Time Navigation",
            description: "Turn-by-turn directions with voice guidance and live traffic updates"
        )

        addFeature(
            icon: "fuelpump.fill",
            title: "Truck Stops & POIs",
            description: "Find truck stops, rest areas, weigh stations, and diesel fuel along your route"
        )

        addFeature(
            icon: "cloud.sun.rain.fill",
            title: "Weather Alerts",
            description: "Get real-time weather conditions and hazard warnings for your journey"
        )

        addFeature(
            icon: "bookmark.fill",
            title: "Save Routes & Favorites",
            description: "Save frequently traveled routes and favorite destinations for quick access"
        )

        // Button action
        getStartedButton.addTarget(self, action: #selector(getStartedTapped), for: .touchUpInside)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Welcome Label
            welcomeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            welcomeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            welcomeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            // Email Label
            emailLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 12),
            emailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            emailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            // Features Stack
            featuresStackView.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 48),
            featuresStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            featuresStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            // Get Started Button
            getStartedButton.topAnchor.constraint(equalTo: featuresStackView.bottomAnchor, constant: 40),
            getStartedButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            getStartedButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            getStartedButton.heightAnchor.constraint(equalToConstant: 54),
            getStartedButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func addFeature(icon: String, title: String, description: String) {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .systemOrange
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(iconView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            iconView.topAnchor.constraint(equalTo: containerView.topAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 2),

            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        featuresStackView.addArrangedSubview(containerView)
    }

    private func loadUserInfo() {
        if let email = AuthManager.shared.getUserEmail() {
            emailLabel.text = email
        }
    }

    // MARK: - Actions

    @objc private func getStartedTapped() {
        // ALWAYS show paywall - no checking
        showPaywall()
    }

    private func showPaywall() {
        let paywall = PaywallViewController()

        // When user completes purchase or closes paywall, proceed to app
        paywall.onComplete = { [weak self] in
            self?.onGetStarted?()
        }

        let navController = UINavigationController(rootViewController: paywall)

        // Always use fullScreen on all devices (including iPad)
        navController.modalPresentationStyle = .fullScreen
        navController.isModalInPresentation = true // Prevent swipe to dismiss

        // Ensure proper presentation on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            navController.modalTransitionStyle = .coverVertical
        }

        present(navController, animated: true)
    }
}
