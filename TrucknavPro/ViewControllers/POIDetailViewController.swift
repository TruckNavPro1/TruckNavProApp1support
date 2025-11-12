//
//  POIDetailViewController.swift
//  TruckNavPro
//
//  Detail view for displaying POI information

import UIKit
import MapboxMaps
import CoreLocation

class POIDetailViewController: UIViewController {

    private let poi: POI
    private var reviews: [POIReview] = []

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

    private let typeIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let amenitiesSection: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let actionButtonsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Initialization

    init(poi: POI) {
        self.poi = poi
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadReviews()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Add header
        contentView.addSubview(typeIconView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(addressLabel)
        contentView.addSubview(amenitiesSection)
        contentView.addSubview(actionButtonsStack)

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

            typeIconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            typeIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            typeIconView.widthAnchor.constraint(equalToConstant: 64),
            typeIconView.heightAnchor.constraint(equalToConstant: 64),

            nameLabel.topAnchor.constraint(equalTo: typeIconView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            ratingLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            ratingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            ratingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            addressLabel.topAnchor.constraint(equalTo: ratingLabel.bottomAnchor, constant: 12),
            addressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            addressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            amenitiesSection.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 24),
            amenitiesSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            amenitiesSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            actionButtonsStack.topAnchor.constraint(equalTo: amenitiesSection.bottomAnchor, constant: 24),
            actionButtonsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            actionButtonsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            actionButtonsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            actionButtonsStack.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Configure content
        configureHeader()
        configureAmenities()
        configureActionButtons()
    }

    private func configureHeader() {
        // Type icon
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold)
        typeIconView.image = UIImage(systemName: poi.type.iconName, withConfiguration: config)
        typeIconView.tintColor = UIColor(hexString: poi.type.markerColor) ?? .systemBlue

        // Name
        nameLabel.text = poi.name

        // Rating
        if let rating = poi.rating, let count = poi.reviewCount {
            ratingLabel.text = String(format: "⭐️ %.1f (\(count) reviews)", rating)
        } else {
            ratingLabel.text = "No ratings yet"
        }

        // Address
        addressLabel.text = poi.fullAddress.isEmpty ? "Address not available" : poi.fullAddress
    }

    private func configureAmenities() {
        // Remove existing amenity views
        amenitiesSection.subviews.forEach { $0.removeFromSuperview() }

        guard !poi.amenities.isEmpty else {
            let noAmenitiesLabel = UILabel()
            noAmenitiesLabel.text = "No amenities listed"
            noAmenitiesLabel.font = .systemFont(ofSize: 15)
            noAmenitiesLabel.textColor = .secondaryLabel
            noAmenitiesLabel.translatesAutoresizingMaskIntoConstraints = false
            amenitiesSection.addSubview(noAmenitiesLabel)
            NSLayoutConstraint.activate([
                noAmenitiesLabel.topAnchor.constraint(equalTo: amenitiesSection.topAnchor),
                noAmenitiesLabel.leadingAnchor.constraint(equalTo: amenitiesSection.leadingAnchor),
                noAmenitiesLabel.trailingAnchor.constraint(equalTo: amenitiesSection.trailingAnchor),
                noAmenitiesLabel.bottomAnchor.constraint(equalTo: amenitiesSection.bottomAnchor)
            ])
            return
        }

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Amenities"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        amenitiesSection.addSubview(titleLabel)

        // Grid of amenities
        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 12
        gridStack.translatesAutoresizingMaskIntoConstraints = false
        amenitiesSection.addSubview(gridStack)

        // Create rows of amenities (2 per row)
        var currentRow: UIStackView?
        for (index, amenity) in poi.amenities.enumerated() {
            if index % 2 == 0 {
                currentRow = UIStackView()
                currentRow?.axis = .horizontal
                currentRow?.spacing = 12
                currentRow?.distribution = .fillEqually
                currentRow?.translatesAutoresizingMaskIntoConstraints = false
                if let row = currentRow {
                    gridStack.addArrangedSubview(row)
                }
            }

            let amenityView = createAmenityView(for: amenity)
            currentRow?.addArrangedSubview(amenityView)
        }

        // Add spacer if odd number of amenities
        if poi.amenities.count % 2 != 0 {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            currentRow?.addArrangedSubview(spacer)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: amenitiesSection.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: amenitiesSection.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: amenitiesSection.trailingAnchor),

            gridStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            gridStack.leadingAnchor.constraint(equalTo: amenitiesSection.leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: amenitiesSection.trailingAnchor),
            gridStack.bottomAnchor.constraint(equalTo: amenitiesSection.bottomAnchor)
        ])
    }

    private func createAmenityView(for amenity: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        icon.image = UIImage(systemName: POIAmenity.iconName(for: amenity), withConfiguration: config)
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = POIAmenity.displayName(for: amenity)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 40),

            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
        ])

        return container
    }

    private func configureActionButtons() {
        // Call button
        if poi.phone != nil {
            let callButton = createActionButton(title: "Call", icon: "phone.fill", color: .systemGreen)
            callButton.addTarget(self, action: #selector(callTapped), for: .touchUpInside)
            actionButtonsStack.addArrangedSubview(callButton)
        }

        // Directions button
        let directionsButton = createActionButton(title: "Directions", icon: "arrow.triangle.turn.up.right.diamond.fill", color: .systemBlue)
        directionsButton.addTarget(self, action: #selector(directionsTapped), for: .touchUpInside)
        actionButtonsStack.addArrangedSubview(directionsButton)

        // Favorite button
        let favoriteButton = createActionButton(title: "Favorite", icon: "heart.fill", color: .systemRed)
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        actionButtonsStack.addArrangedSubview(favoriteButton)
    }

    private func createActionButton(title: String, icon: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .white
        button.backgroundColor = color
        button.layer.cornerRadius = 12
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        return button
    }

    // MARK: - Actions

    @objc private func callTapped() {
        guard let phone = poi.phone,
              let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") else {
            return
        }
        UIApplication.shared.open(url)
    }

    @objc private func directionsTapped() {
        // Open in Apple Maps
        guard let url = URL(string: "maps://?daddr=\(poi.latitude),\(poi.longitude)") else {
            showError("Unable to open Maps")
            return
        }
        UIApplication.shared.open(url)
    }

    @objc private func favoriteTapped() {
        Task {
            do {
                try await POIService.shared.addToFavorites(poiId: poi.id)
                showSuccess("Added to favorites!")
            } catch {
                showError("Failed to add favorite: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Load Reviews

    private func loadReviews() {
        Task {
            do {
                reviews = try await POIService.shared.fetchReviews(for: poi.id)
                print("✅ Loaded \(reviews.count) reviews for \(poi.name)")
            } catch {
                print("❌ Failed to load reviews: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSuccess(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}
