//
//  LoginViewController.swift
//  TruckNavPro
//
//  User authentication screen with sign in and sign up

import UIKit

class LoginViewController: UIViewController {

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

    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "truck.box.fill")
        iv.tintColor = .systemOrange
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "TruckNav Pro"
        label.font = .systemFont(ofSize: 36, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Professional Truck Navigation"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.keyboardType = .emailAddress
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 16)
        tf.backgroundColor = .secondarySystemBackground
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let passwordTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Password"
        tf.isSecureTextEntry = true
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 16)
        tf.backgroundColor = .secondarySystemBackground
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let signInButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Sign In", for: .normal)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create Account", for: .normal)
        button.backgroundColor = .clear
        button.setTitleColor(.systemOrange, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.systemOrange.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue without account", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Properties

    var onAuthenticationSuccess: (() -> Void)?
    var onSkipAuthentication: (() -> Void)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardHandling()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(logoImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(emailTextField)
        contentView.addSubview(passwordTextField)
        contentView.addSubview(signInButton)
        contentView.addSubview(signUpButton)
        contentView.addSubview(skipButton)
        view.addSubview(activityIndicator)

        // Button actions
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

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

            // Logo
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),

            // Title
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            // Email
            emailTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 48),
            emailTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            emailTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),

            // Password
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
            passwordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            passwordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),

            // Sign In Button
            signInButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 32),
            signInButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            signInButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            signInButton.heightAnchor.constraint(equalToConstant: 54),

            // Sign Up Button
            signUpButton.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: 16),
            signUpButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            signUpButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            signUpButton.heightAnchor.constraint(equalToConstant: 54),

            // Skip Button
            skipButton.topAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: 24),
            skipButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),

            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupKeyboardHandling() {
        // Dismiss keyboard on tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)

        // Keyboard notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    // MARK: - Actions

    @objc private func signInTapped() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter email and password")
            return
        }

        Task {
            await performSignIn(email: email, password: password)
        }
    }

    @objc private func signUpTapped() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter email and password")
            return
        }

        if password.count < 6 {
            showAlert(title: "Error", message: "Password must be at least 6 characters")
            return
        }

        Task {
            await performSignUp(email: email, password: password)
        }
    }

    @objc private func skipTapped() {
        onSkipAuthentication?()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }

    // MARK: - Authentication

    private func performSignIn(email: String, password: String) async {
        await MainActor.run {
            activityIndicator.startAnimating()
            signInButton.isEnabled = false
            signUpButton.isEnabled = false
        }

        do {
            try await AuthManager.shared.signIn(email: email, password: password)

            await MainActor.run {
                activityIndicator.stopAnimating()
                signInButton.isEnabled = true
                signUpButton.isEnabled = true
                onAuthenticationSuccess?()
            }

            print("✅ Sign in successful")
        } catch {
            await MainActor.run {
                activityIndicator.stopAnimating()
                signInButton.isEnabled = true
                signUpButton.isEnabled = true
                showAlert(title: "Sign In Failed", message: error.localizedDescription)
            }

            print("❌ Sign in failed: \(error.localizedDescription)")
        }
    }

    private func performSignUp(email: String, password: String) async {
        await MainActor.run {
            activityIndicator.startAnimating()
            signInButton.isEnabled = false
            signUpButton.isEnabled = false
        }

        do {
            try await AuthManager.shared.signUp(email: email, password: password)

            await MainActor.run {
                activityIndicator.stopAnimating()
                signInButton.isEnabled = true
                signUpButton.isEnabled = true
                onAuthenticationSuccess?()
            }

            print("✅ Sign up successful")
        } catch {
            await MainActor.run {
                activityIndicator.stopAnimating()
                signInButton.isEnabled = true
                signUpButton.isEnabled = true
                showAlert(title: "Sign Up Failed", message: error.localizedDescription)
            }

            print("❌ Sign up failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
