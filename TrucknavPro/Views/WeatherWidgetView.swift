//
//  WeatherWidgetView.swift
//  TruckNavPro
//

import UIKit

class WeatherWidgetView: UIView {

    // Cache for SF Symbol images to avoid recreating them on every update
    private static let imageCache = NSCache<NSString, UIImage>()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let weatherIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let temperatureLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let dayLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.9)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let conditionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let highLowLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.9)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Apple Weather attribution (required by Apple)
    private let attributionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = true
        return stack
    }()

    private let appleLogoImageView: UIImageView = {
        let imageView = UIImageView()
        // Use the Apple logo SF Symbol
        imageView.image = UIImage(systemName: "applelogo")
        imageView.tintColor = .white.withAlphaComponent(0.8)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let weatherAttributionLabel: UILabel = {
        let label = UILabel()
        label.text = "Weather"
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        addSubview(containerView)

        // Create stack for text info
        let textStack = UIStackView(arrangedSubviews: [dayLabel, temperatureLabel, conditionLabel, highLowLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // Setup attribution stack with Apple logo and text
        attributionStackView.addArrangedSubview(appleLogoImageView)
        attributionStackView.addArrangedSubview(weatherAttributionLabel)

        containerView.addSubview(weatherIcon)
        containerView.addSubview(textStack)
        containerView.addSubview(attributionStackView)

        // Add tap gesture for attribution link
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(attributionTapped))
        attributionStackView.addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            weatherIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            weatherIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            weatherIcon.widthAnchor.constraint(equalToConstant: 36),
            weatherIcon.heightAnchor.constraint(equalToConstant: 36),

            textStack.leadingAnchor.constraint(equalTo: weatherIcon.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            textStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: attributionStackView.topAnchor, constant: -4),

            // Apple Weather attribution at bottom - properly aligned
            attributionStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            attributionStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),

            // Apple logo size constraints
            appleLogoImageView.widthAnchor.constraint(equalToConstant: 10),
            appleLogoImageView.heightAnchor.constraint(equalToConstant: 12)
        ])

        // Show default placeholder until weather data loads
        temperatureLabel.text = "--°"
        weatherIcon.image = getCachedSymbol("cloud.sun.fill")
        dayLabel.text = "Loading..."
        conditionLabel.text = ""
        highLowLabel.text = ""
    }

    func configure(with weatherInfo: WeatherInfo) {
        temperatureLabel.text = "\(weatherInfo.temperature)°"
        weatherIcon.image = getCachedSymbol(weatherInfo.symbolName)
        dayLabel.text = weatherInfo.dayName
        conditionLabel.text = weatherInfo.condition
        highLowLabel.text = "H:\(weatherInfo.high)° L:\(weatherInfo.low)°"
    }

    // MARK: - Actions

    @objc private func attributionTapped() {
        // Open Apple Weather attribution link
        if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Image Caching

    /// Get SF Symbol from cache or create and cache it
    private func getCachedSymbol(_ name: String) -> UIImage? {
        let key = name as NSString

        // Check cache first
        if let cachedImage = WeatherWidgetView.imageCache.object(forKey: key) {
            return cachedImage
        }

        // Create and cache the image
        if let image = UIImage(systemName: name) {
            WeatherWidgetView.imageCache.setObject(image, forKey: key)
            return image
        }

        return nil
    }
}
