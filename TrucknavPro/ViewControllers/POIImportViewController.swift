//
//  POIImportViewController.swift
//  TruckNavPro
//
//  Admin utility for importing POI data from external APIs

import UIKit

class POIImportViewController: UIViewController {

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

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "POI Data Import"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Import real-world truck stop, rest area, and weigh station data from OpenStreetMap."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.isHidden = true
        return progress
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var importMajorRoutesButton: UIButton = {
        let button = createButton(
            title: "Import Major US Routes",
            subtitle: "I-10, I-40, I-80, I-95",
            icon: "map.fill",
            color: .systemBlue
        )
        button.addTarget(self, action: #selector(importMajorRoutesTapped), for: .touchUpInside)
        return button
    }()

    private lazy var importCustomRegionButton: UIButton = {
        let button = createButton(
            title: "Import Custom Region",
            subtitle: "Specify lat/lon bounds",
            icon: "mappin.and.ellipse",
            color: .systemGreen
        )
        button.addTarget(self, action: #selector(importCustomRegionTapped), for: .touchUpInside)
        return button
    }()

    private lazy var importSingleStateButton: UIButton = {
        let button = createButton(
            title: "Import Single State",
            subtitle: "Quick state-wide import",
            icon: "location.fill",
            color: .systemOrange
        )
        button.addTarget(self, action: #selector(importStateTapped), for: .touchUpInside)
        return button
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(importMajorRoutesButton)
        contentView.addSubview(importCustomRegionButton)
        contentView.addSubview(importSingleStateButton)
        contentView.addSubview(progressView)
        contentView.addSubview(statusLabel)
        contentView.addSubview(activityIndicator)
        contentView.addSubview(closeButton)

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

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            importMajorRoutesButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            importMajorRoutesButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            importMajorRoutesButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            importMajorRoutesButton.heightAnchor.constraint(equalToConstant: 80),

            importCustomRegionButton.topAnchor.constraint(equalTo: importMajorRoutesButton.bottomAnchor, constant: 16),
            importCustomRegionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            importCustomRegionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            importCustomRegionButton.heightAnchor.constraint(equalToConstant: 80),

            importSingleStateButton.topAnchor.constraint(equalTo: importCustomRegionButton.bottomAnchor, constant: 16),
            importSingleStateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            importSingleStateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            importSingleStateButton.heightAnchor.constraint(equalToConstant: 80),

            progressView.topAnchor.constraint(equalTo: importSingleStateButton.bottomAnchor, constant: 40),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            closeButton.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 40),
            closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func createButton(title: String, subtitle: String, icon: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = color.withAlphaComponent(0.1)
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false

        // Create stack view for content
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = color
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 40).isActive = true

        // Text stack
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = color

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(textStack)

        button.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: button.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -16)
        ])

        return button
    }

    // MARK: - Actions

    @objc private func importMajorRoutesTapped() {
        let alert = UIAlertController(
            title: "Import Major US Routes",
            message: "This will import POIs along I-10, I-40, I-80, and I-95. This may take 10-15 minutes and will add thousands of POIs.\n\nContinue?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            self?.startImport(type: .majorRoutes)
        })

        present(alert, animated: true)
    }

    @objc private func importCustomRegionTapped() {
        let alert = UIAlertController(
            title: "Import Custom Region",
            message: "Enter bounding box coordinates:",
            preferredStyle: .alert
        )

        alert.addTextField { $0.placeholder = "Min Latitude" }
        alert.addTextField { $0.placeholder = "Min Longitude" }
        alert.addTextField { $0.placeholder = "Max Latitude" }
        alert.addTextField { $0.placeholder = "Max Longitude" }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            guard let minLat = Double(alert.textFields?[0].text ?? ""),
                  let minLon = Double(alert.textFields?[1].text ?? ""),
                  let maxLat = Double(alert.textFields?[2].text ?? ""),
                  let maxLon = Double(alert.textFields?[3].text ?? "") else {
                self?.showError("Invalid coordinates")
                return
            }

            self?.startImport(type: .customRegion(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon))
        })

        present(alert, animated: true)
    }

    @objc private func importStateTapped() {
        // Show state picker
        let stateRegions = USStateRegions.all

        let alert = UIAlertController(title: "Select State", message: nil, preferredStyle: .actionSheet)

        for state in stateRegions {
            alert.addAction(UIAlertAction(title: state.name, style: .default) { [weak self] _ in
                self?.startImport(type: .customRegion(
                    minLat: state.minLat,
                    minLon: state.minLon,
                    maxLat: state.maxLat,
                    maxLon: state.maxLon
                ))
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = importSingleStateButton
            popover.sourceRect = importSingleStateButton.bounds
        }

        present(alert, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Import Logic

    private enum ImportType {
        case majorRoutes
        case customRegion(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)
    }

    private func startImport(type: ImportType) {
        // Disable buttons
        importMajorRoutesButton.isEnabled = false
        importCustomRegionButton.isEnabled = false
        importSingleStateButton.isEnabled = false

        // Show progress
        progressView.isHidden = false
        statusLabel.isHidden = false
        activityIndicator.startAnimating()

        Task {
            do {
                switch type {
                case .majorRoutes:
                    try await POIImportService.shared.importMajorTruckingRoutes { [weak self] status, current, total in
                        DispatchQueue.main.async {
                            self?.updateProgress(status: status, current: current, total: total)
                        }
                    }

                case .customRegion(let minLat, let minLon, let maxLat, let maxLon):
                    try await POIImportService.shared.importPOIsForRegion(
                        minLat: minLat,
                        minLon: minLon,
                        maxLat: maxLat,
                        maxLon: maxLon
                    ) { [weak self] status, current, total in
                        DispatchQueue.main.async {
                            self?.updateProgress(status: status, current: current, total: total)
                        }
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    self?.importComplete()
                }

            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.showError(error.localizedDescription)
                    self?.resetUI()
                }
            }
        }
    }

    private func updateProgress(status: String, current: Int, total: Int) {
        statusLabel.text = status
        progressView.progress = Float(current) / Float(total)
    }

    private func importComplete() {
        activityIndicator.stopAnimating()
        statusLabel.text = "✅ Import complete! POIs are now available in the app."
        statusLabel.textColor = .systemGreen

        // Show success alert
        let alert = UIAlertController(
            title: "Import Complete",
            message: "POI data has been successfully imported to your database.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        resetUI()
    }

    private func resetUI() {
        importMajorRoutesButton.isEnabled = true
        importCustomRegionButton.isEnabled = true
        importSingleStateButton.isEnabled = true
        activityIndicator.stopAnimating()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - US State Regions

struct USStateRegion {
    let name: String
    let minLat: Double
    let minLon: Double
    let maxLat: Double
    let maxLon: Double
}

struct USStateRegions {
    static let all: [USStateRegion] = [
        USStateRegion(name: "California", minLat: 32.5, minLon: -124.5, maxLat: 42.0, maxLon: -114.1),
        USStateRegion(name: "Texas", minLat: 25.8, minLon: -106.6, maxLat: 36.5, maxLon: -93.5),
        USStateRegion(name: "Florida", minLat: 24.5, minLon: -87.6, maxLat: 31.0, maxLon: -80.0),
        USStateRegion(name: "New York", minLat: 40.5, minLon: -79.8, maxLat: 45.0, maxLon: -71.8),
        USStateRegion(name: "Pennsylvania", minLat: 39.7, minLon: -80.5, maxLat: 42.3, maxLon: -74.7),
        USStateRegion(name: "Illinois", minLat: 37.0, minLon: -91.5, maxLat: 42.5, maxLon: -87.5),
        USStateRegion(name: "Ohio", minLat: 38.4, minLon: -84.8, maxLat: 42.3, maxLon: -80.5),
        USStateRegion(name: "Georgia", minLat: 30.4, minLon: -85.6, maxLat: 35.0, maxLon: -80.8),
        USStateRegion(name: "North Carolina", minLat: 33.8, minLon: -84.3, maxLat: 36.6, maxLon: -75.4),
        USStateRegion(name: "Michigan", minLat: 41.7, minLon: -90.4, maxLat: 48.3, maxLon: -82.4),
        USStateRegion(name: "Tennessee", minLat: 35.0, minLon: -90.3, maxLat: 36.7, maxLon: -81.6),
        USStateRegion(name: "Arizona", minLat: 31.3, minLon: -114.8, maxLat: 37.0, maxLon: -109.0),
        USStateRegion(name: "Indiana", minLat: 37.8, minLon: -88.1, maxLat: 41.8, maxLon: -84.8),
        USStateRegion(name: "Missouri", minLat: 36.0, minLon: -95.8, maxLat: 40.6, maxLon: -89.1),
        USStateRegion(name: "Nevada", minLat: 35.0, minLon: -120.0, maxLat: 42.0, maxLon: -114.0)
    ]
}
