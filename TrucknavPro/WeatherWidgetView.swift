//
//  WeatherWidgetView.swift
//  TruckNavPro
//

import UIKit

class WeatherWidgetView: UIView {

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.layer.cornerRadius = 12
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
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
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
        containerView.addSubview(weatherIcon)
        containerView.addSubview(temperatureLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            weatherIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            weatherIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            weatherIcon.widthAnchor.constraint(equalToConstant: 28),
            weatherIcon.heightAnchor.constraint(equalToConstant: 28),

            temperatureLabel.leadingAnchor.constraint(equalTo: weatherIcon.trailingAnchor, constant: 8),
            temperatureLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            temperatureLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])

        // Show default placeholder until weather data loads
        temperatureLabel.text = "--°"
        weatherIcon.image = UIImage(systemName: "cloud.sun.fill")
    }

    func configure(temperature: Int, symbolName: String) {
        temperatureLabel.text = "\(temperature)°"
        weatherIcon.image = UIImage(systemName: symbolName)
    }
}
