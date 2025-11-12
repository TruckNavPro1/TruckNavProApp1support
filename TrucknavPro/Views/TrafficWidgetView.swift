//
//  TrafficWidgetView.swift
//  TruckNavPro
//
//  Live traffic widget with real-time updates
//

import UIKit
import CoreLocation

class TrafficWidgetView: UIView {

    // MARK: - Properties

    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 30  // Update every 30 seconds

    // MARK: - UI Components

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

    private let statusIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Traffic"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.9)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let speedLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.85)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let incidentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.8)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        showLoading()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        showLoading()
    }

    deinit {
        stopAutoUpdate()
    }

    // MARK: - Setup

    private func setupView() {
        addSubview(containerView)

        // Create stack for text info
        let textStack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, speedLabel, incidentLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(statusIcon)
        containerView.addSubview(textStack)
        containerView.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            statusIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            statusIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            statusIcon.widthAnchor.constraint(equalToConstant: 36),
            statusIcon.heightAnchor.constraint(equalToConstant: 36),

            textStack.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            textStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            activityIndicator.centerXAnchor.constraint(equalTo: statusIcon.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: statusIcon.centerYAnchor)
        ])
    }

    // MARK: - Configuration

    func configure(
        congestionLevel: TrafficCongestionLevel,
        currentSpeed: Int,
        freeFlowSpeed: Int,
        nearbyIncidents: [String]
    ) {
        activityIndicator.stopAnimating()
        statusIcon.isHidden = false

        // Set status and icon based on congestion
        let (status, icon, color) = congestionLevel.display
        statusLabel.text = status
        statusIcon.image = UIImage(systemName: icon)
        statusIcon.tintColor = color

        // Speed info
        if currentSpeed > 0 {
            speedLabel.text = "\(currentSpeed) mph (avg: \(freeFlowSpeed) mph)"
        } else {
            speedLabel.text = "Speed data unavailable"
        }

        // Incident info
        if !nearbyIncidents.isEmpty {
            incidentLabel.text = "⚠️ \(nearbyIncidents.count) incident(s) nearby"
        } else {
            incidentLabel.text = "No incidents reported"
        }

        print("🚦 Traffic widget updated: \(status)")
    }

    func showLoading() {
        statusIcon.isHidden = true
        activityIndicator.startAnimating()
        statusLabel.text = "Loading..."
        speedLabel.text = ""
        incidentLabel.text = ""
    }

    func showError(_ message: String) {
        activityIndicator.stopAnimating()
        statusIcon.isHidden = false
        statusIcon.image = UIImage(systemName: "exclamationmark.triangle.fill")
        statusIcon.tintColor = .systemYellow
        statusLabel.text = "Traffic Unavailable"
        speedLabel.text = message
        incidentLabel.text = ""
    }

    // MARK: - Auto-Update

    func startAutoUpdate(
        location: CLLocationCoordinate2D,
        hereService: HERETrafficService?,
        tomTomService: TomTomTrafficService?
    ) {
        stopAutoUpdate()

        // Initial fetch
        fetchTrafficData(location: location, hereService: hereService, tomTomService: tomTomService)

        // Setup timer for periodic updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.fetchTrafficData(location: location, hereService: hereService, tomTomService: tomTomService)
        }

        print("🚦 Traffic auto-update started (every \(Int(updateInterval))s)")
    }

    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("🚦 Traffic auto-update stopped")
    }

    private func fetchTrafficData(
        location: CLLocationCoordinate2D,
        hereService: HERETrafficService?,
        tomTomService: TomTomTrafficService?
    ) {
        showLoading()

        // Try HERE first (primary)
        if let here = hereService {
            print("🚦 Widget using HERE Traffic (primary)...")
            fetchHERETraffic(location: location, service: here, tomTomFallback: tomTomService)
        } else if let tomTom = tomTomService {
            print("🚦 Widget using TomTom Traffic (fallback)...")
            fetchTomTomTraffic(location: location, service: tomTom)
        } else {
            showError("No traffic services available")
            print("❌ Widget: No traffic services configured")
        }
    }

    private func fetchHERETraffic(
        location: CLLocationCoordinate2D,
        service: HERETrafficService,
        tomTomFallback: TomTomTrafficService?
    ) {
        // Fetch traffic flow from HERE
        service.getTrafficFlow(at: location) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let flow):
                    // Map HERE jam factor to congestion level
                    let congestion: TrafficCongestionLevel
                    if flow.jamFactor >= 8.0 {
                        congestion = .heavy
                    } else if flow.jamFactor >= 5.0 {
                        congestion = .congestion
                    } else if flow.jamFactor >= 2.0 {
                        congestion = .slow
                    } else {
                        congestion = .freeFlow
                    }

                    // Convert speeds from km/h to mph
                    let currentSpeedMph = Int(flow.currentSpeed * 0.621371)
                    let freeFlowSpeedMph = Int(flow.freeFlowSpeed * 0.621371)

                    // Fetch nearby incidents (within 10km radius)
                    let bbox = self?.getBoundingBox(center: location, radiusKm: 10) ?? (0, 0, 0, 0)
                    service.getTrafficIncidents(in: bbox) { incidentResult in
                        DispatchQueue.main.async {
                            let incidents = (try? incidentResult.get()) ?? []
                            let incidentDescriptions = incidents.prefix(3).map { $0.description }

                            self?.configure(
                                congestionLevel: congestion,
                                currentSpeed: currentSpeedMph,
                                freeFlowSpeed: freeFlowSpeedMph,
                                nearbyIncidents: incidentDescriptions
                            )
                        }
                    }

                case .failure(let error):
                    print("❌ Widget HERE Traffic failed: \(error.localizedDescription)")
                    // Try TomTom fallback
                    if let tomTom = tomTomFallback {
                        print("🔄 Widget falling back to TomTom Traffic...")
                        self?.fetchTomTomTraffic(location: location, service: tomTom)
                    } else {
                        self?.showError("Traffic data unavailable")
                    }
                }
            }
        }
    }

    private func fetchTomTomTraffic(location: CLLocationCoordinate2D, service: TomTomTrafficService) {
        // Fetch traffic flow from TomTom
        service.getTrafficFlow(at: location) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let flow):
                    // Determine congestion level
                    let congestion = TrafficCongestionLevel(rawValue: flow.congestion) ?? .freeFlow

                    // Fetch nearby incidents (within 10km radius)
                    let bbox = self?.getBoundingBox(center: location, radiusKm: 10) ?? (0, 0, 0, 0)
                    service.getTrafficIncidents(in: bbox) { incidentResult in
                        DispatchQueue.main.async {
                            let incidents = (try? incidentResult.get()) ?? []
                            let incidentDescriptions = incidents.prefix(3).map { $0.description }

                            self?.configure(
                                congestionLevel: congestion,
                                currentSpeed: flow.currentSpeed,
                                freeFlowSpeed: flow.freeFlowSpeed,
                                nearbyIncidents: incidentDescriptions
                            )
                        }
                    }

                case .failure(let error):
                    self?.showError("Traffic data unavailable")
                    print("❌ Widget TomTom Traffic failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func getBoundingBox(
        center: CLLocationCoordinate2D,
        radiusKm: Double
    ) -> (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) {
        // Rough approximation: 1 degree latitude ≈ 111 km
        let latOffset = radiusKm / 111.0
        let lonOffset = radiusKm / (111.0 * cos(center.latitude * .pi / 180))

        return (
            minLat: center.latitude - latOffset,
            minLon: center.longitude - lonOffset,
            maxLat: center.latitude + latOffset,
            maxLon: center.longitude + lonOffset
        )
    }
}

// MARK: - Traffic Congestion Level

enum TrafficCongestionLevel: Int {
    case freeFlow = 0
    case slow = 1
    case congestion = 2
    case heavy = 3

    var display: (status: String, icon: String, color: UIColor) {
        switch self {
        case .freeFlow:
            return ("Free Flow", "checkmark.circle.fill", .systemGreen)
        case .slow:
            return ("Slow Traffic", "minus.circle.fill", .systemYellow)
        case .congestion:
            return ("Congestion", "exclamationmark.circle.fill", .systemOrange)
        case .heavy:
            return ("Heavy Traffic", "xmark.circle.fill", .systemRed)
        }
    }
}
