//
//  NavigationViewController.swift
//  TruckNavPro
//

import UIKit
import MapboxMaps
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxSearchUI
import CoreLocation
import Combine

class MapViewController: UIViewController {

    private var navigationMapView: NavigationMapView!
    private let locationManager = CLLocationManager()
    private var cancelables = Set<AnyCancellable>()
    private var lastBearing: CLLocationDirection = 0

    // Mapbox Navigation Provider (v3)
    private var navigationProvider: MapboxNavigationProvider!
    private var mapboxNavigation: MapboxNavigation!
    private var currentNavigationViewController: NavigationViewController?

    // Standard US Semi-Trailer Parameters (for Mapbox Directions API)
    private let truckHeight: Measurement<UnitLength> = Measurement(value: 4.11, unit: .meters)  // 13'6"
    private let truckWidth: Measurement<UnitLength> = Measurement(value: 2.44, unit: .meters)   // 8 ft
    private let truckWeight: Measurement<UnitMass> = Measurement(value: 36.287, unit: .metricTons) // 80,000 lbs

    // Navigation state
    private var isNavigating: Bool = false
    private var isFreeDriveActive: Bool = false
    private var currentNavigationRoutes: NavigationRoutes?

    // Free-drive mode UI (Mapbox drop-in components)
    private let speedLimitView = SpeedLimitView()
    private let roadNameLabel = UILabel()

    // Simple route preview buttons (Mapbox showcase() handles the route display)
    private let routePreviewContainer = UIView()
    private let startNavigationButton = UIButton(type: .system)
    private let cancelRouteButton = UIButton(type: .system)

    // MapboxSearchUI drop-in component
    private var searchController: MapboxSearchController!
    private var panelController: MapboxPanelController!

    // Search result annotations
    private var pointAnnotationManager: PointAnnotationManager!
    private var currentSearchResults: [SearchResult] = []

    // Weather update tracking
    private var lastWeatherUpdateTime: Date?

    // TomTom Services
    private var tomTomRoutingService: TomTomRoutingService?
    private var tomTomTrafficService: TomTomTrafficService?
    private var tomTomSearchService: TomTomSearchService?
    private var trafficUpdateTimer: Timer?
    private var incidentAnnotationManager: PointAnnotationManager?

    private lazy var recenterButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "location.fill", withConfiguration: config), for: .normal)
        button.backgroundColor = .systemBackground
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(recenterMap), for: .touchUpInside)
        return button
    }()

    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "gearshape.fill", withConfiguration: config), for: .normal)
        button.backgroundColor = .systemBackground
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        return button
    }()

    private let weatherWidget: WeatherWidgetView = {
        let widget = WeatherWidgetView()
        widget.translatesAutoresizingMaskIntoConstraints = false
        return widget
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize Mapbox Navigation Provider (v3)
        let coreConfig = CoreConfig()
        navigationProvider = MapboxNavigationProvider(coreConfig: coreConfig)
        mapboxNavigation = navigationProvider.mapboxNavigation

        // Initialize TomTom Services if API key available
        if let tomTomApiKey = Bundle.main.infoDictionary?["TomTomAPIKey"] as? String {
            tomTomRoutingService = TomTomRoutingService(apiKey: tomTomApiKey)
            tomTomTrafficService = TomTomTrafficService(apiKey: tomTomApiKey)
            tomTomSearchService = TomTomSearchService(apiKey: tomTomApiKey)
            print("🚛 TomTom Services initialized (Routing, Traffic, Search)")
        } else {
            print("⚠️ TomTom API key not found - using Mapbox only")
        }

        setupLocationManager()
        setupMapView()
        setupSearchController()
        setupFreeDriveUI()
        setupRoutePreviewUI()
        setupRecenterButton()
        setupSettingsButton()
        setupWeatherWidget()

        // Ensure proper z-ordering (bring controls to front)
        view.bringSubviewToFront(recenterButton)
        view.bringSubviewToFront(settingsButton)
        view.bringSubviewToFront(weatherWidget)
        view.bringSubviewToFront(speedLimitView)
        view.bringSubviewToFront(roadNameLabel)

        // Start free-drive mode for passive location tracking
        startFreeDriveMode()

        print("🚛 TruckNav Pro initialized with Mapbox Navigation SDK v3")
    }

    // MARK: - Truck Configuration Helpers

    /// Configure route options with truck parameters
    private func configureTruckRouteOptions(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> NavigationRouteOptions {
        // Create waypoints
        let waypoints = [origin, destination]

        let options = NavigationRouteOptions(coordinates: waypoints)

        // Set truck-specific parameters
        options.maximumHeight = truckHeight
        options.maximumWidth = truckWidth
        options.maximumWeight = truckWeight

        // Avoid unpaved roads and tunnels (for safety and hazmat)
        options.roadClassesToAvoid = [.unpaved]

        // Request route alternatives
        options.includesAlternativeRoutes = true

        // Enable detailed annotations for navigation
        options.attributeOptions = [.speed, .distance, .expectedTravelTime, .congestionLevel]

        print("🚛 Truck routing configured: \(truckHeight.value)m height, \(truckWidth.value)m width, \(truckWeight.value)t weight")

        return options
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation

        // Request "Always" authorization for background turn-by-turn navigation
        locationManager.requestAlwaysAuthorization()

        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    private func setupMapView() {
        // Create NavigationMapView for route preview and navigation (v3 syntax)
        navigationMapView = NavigationMapView(
            location: navigationProvider.mapboxNavigation.navigation().locationMatching
                .map(\.enhancedLocation)  // ✅ FIXED: Correct path (was .mapMatchingResult.enhancedLocation)
                .eraseToAnyPublisher(),
            routeProgress: navigationProvider.mapboxNavigation.navigation().routeProgress
                .map(\.?.routeProgress)
                .eraseToAnyPublisher(),
            heading: navigationProvider.mapboxNavigation.navigation().heading,
            predictiveCacheManager: navigationProvider.predictiveCacheManager
        )
        navigationMapView.frame = view.bounds
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Use 2D puck for maximum reliability (Mapbox recommended)
        navigationMapView.puckType = .puck2D(.navigationDefault)

        // Enable bearing tracking for directional indicator
        navigationMapView.mapView.location.options.puckBearingEnabled = true

        view.addSubview(navigationMapView)

        navigationMapView.mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
            self?.enable3DBuildings()
            self?.setupAnnotationManager()
            self?.configureDayNightMode()
            print("✅ NavigationMapView loaded - ready for free-drive")
        }.store(in: &cancelables)
    }

    private func enable3DBuildings() {
        do {
            var layer = FillExtrusionLayer(id: "3d-buildings", source: "composite")
            layer.sourceLayer = "building"
            layer.minZoom = 15
            layer.fillExtrusionHeight = .expression(Exp(.get) { "height" })
            layer.fillExtrusionBase = .expression(Exp(.get) { "min_height" })
            layer.fillExtrusionColor = .constant(StyleColor(.lightGray))
            layer.fillExtrusionOpacity = .constant(0.6)

            try navigationMapView.mapView.mapboxMap.addLayer(layer)
            print("✅ 3D buildings enabled")
        } catch {
            print("⚠️ 3D buildings error: \(error)")
        }
    }

    private func setupAnnotationManager() {
        // Create annotation manager for search results
        pointAnnotationManager = navigationMapView.mapView.annotations.makePointAnnotationManager()

        // Handle annotation taps via delegate
        pointAnnotationManager.delegate = self

        // Create annotation manager for traffic incidents
        incidentAnnotationManager = navigationMapView.mapView.annotations.makePointAnnotationManager()

        print("✅ Annotation managers initialized")
    }

    private func configureDayNightMode() {
        // Set map style based on system color scheme
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let lightPreset = isDarkMode ? "night" : "day"

        do {
            try navigationMapView.mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: lightPreset
            )
            print("🌓 Map style set to \(lightPreset) mode")
        } catch {
            print("⚠️ Error setting map light preset: \(error)")
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Update map style when system appearance changes
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            configureDayNightMode()
        }
    }

    private func setupSearchController() {
        // Initialize MapboxSearchUI SearchController (drop-in component)
        searchController = MapboxSearchController(apiType: .searchBox)
        searchController.delegate = self

        // Configure search options with user location proximity
        configureSearchProximity()

        // Wrap in MapboxPanelController (sliding drawer UI)
        panelController = MapboxPanelController(rootViewController: searchController)

        // Add as child view controller to embed the search panel
        addChild(panelController)
        view.addSubview(panelController.view)
        panelController.didMove(toParent: self)

        print("✅ MapboxSearchUI SearchController initialized with panel drawer")
    }

    private func configureSearchProximity() {
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ User location not available yet for search proximity")
            return
        }

        var searchOptions = SearchOptions()
        searchOptions.proximity = userLocation
        searchOptions.limit = UserDefaults.standard.integer(forKey: "POIResultCount") > 0 ?
            UserDefaults.standard.integer(forKey: "POIResultCount") : 10

        searchController.searchOptions = searchOptions

        print("📍 Search proximity set to: lat=\(String(format: "%.4f", userLocation.latitude)), lon=\(String(format: "%.4f", userLocation.longitude)), limit=\(searchOptions.limit ?? 10)")
    }

    private func setupRecenterButton() {
        view.addSubview(recenterButton)

        NSLayoutConstraint.activate([
            recenterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            recenterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            recenterButton.widthAnchor.constraint(equalToConstant: 44),
            recenterButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func recenterMap() {
        // Resume camera following mode for free-drive
        if !isNavigating {
            navigationMapView.navigationCamera.update(cameraState: .following)
            print("📍 Camera following user bearing")
        } else {
            // During navigation, just recenter manually
            guard let userLocation = locationManager.location?.coordinate else { return }

            let cameraOptions = CameraOptions(
                center: userLocation,
                padding: UIEdgeInsets(top: 0, left: 0, bottom: view.bounds.height * 0.4, right: 0),
                zoom: 17,
                bearing: lastBearing,
                pitch: 60
            )

            navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 1.5, curve: .easeInOut, completion: nil)
            print("📍 Map recentered to current location")
        }
    }

    private func setupSettingsButton() {
        view.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            settingsButton.bottomAnchor.constraint(equalTo: recenterButton.topAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupWeatherWidget() {
        view.addSubview(weatherWidget)

        NSLayoutConstraint.activate([
            weatherWidget.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            weatherWidget.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            weatherWidget.widthAnchor.constraint(lessThanOrEqualToConstant: 180)
        ])

        // Fetch weather for initial location
        if let location = locationManager.location {
            fetchWeather(for: location.coordinate)
        }
    }

    private func fetchWeather(for coordinate: CLLocationCoordinate2D) {
        WeatherService.shared.fetchWeather(for: coordinate) { [weak self] result in
            switch result {
            case .success(let weatherInfo):
                self?.weatherWidget.configure(with: weatherInfo)
                print("🌤️ Weather updated: \(weatherInfo.temperature)° \(weatherInfo.condition)")
            case .failure(let error):
                print("⚠️ Weather fetch failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.modalPresentationStyle = .pageSheet
        if let sheet = settingsVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(settingsVC, animated: true)
        print("⚙️ Opening settings")
    }

    // MARK: - Free-Drive Mode UI

    private func setupFreeDriveUI() {
        // Speed Limit View (Mapbox drop-in component)
        speedLimitView.translatesAutoresizingMaskIntoConstraints = false
        speedLimitView.isHidden = true
        view.addSubview(speedLimitView)

        // Road Name Label
        roadNameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        roadNameLabel.textColor = .label
        roadNameLabel.textAlignment = .center
        roadNameLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        roadNameLabel.layer.cornerRadius = 8
        roadNameLabel.clipsToBounds = true
        roadNameLabel.translatesAutoresizingMaskIntoConstraints = false
        roadNameLabel.isHidden = true
        view.addSubview(roadNameLabel)

        NSLayoutConstraint.activate([
            // Speed limit in top-right corner
            speedLimitView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            speedLimitView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            speedLimitView.widthAnchor.constraint(equalToConstant: 70),
            speedLimitView.heightAnchor.constraint(equalToConstant: 70),

            // Road name at bottom
            roadNameLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            roadNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            roadNameLabel.heightAnchor.constraint(equalToConstant: 40),
            roadNameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
    }

    private func startFreeDriveMode() {
        // Start Mapbox free-drive mode (passive navigation)
        // Note: Can be called multiple times - Mapbox handles restart internally
        navigationProvider.tripSession().startFreeDrive()

        // Keep flags in lockstep
        isFreeDriveActive = true
        isNavigating = false

        // Enable camera to follow user bearing (heading direction)
        navigationMapView.navigationCamera.update(cameraState: .following)

        // Only create subscription once
        if cancelables.isEmpty {
            // Subscribe to location matching for speed limit and road name
            navigationProvider.mapboxNavigation.navigation().locationMatching.sink { [weak self] state in
                guard let self = self, !self.isNavigating else { return }

                // Update speed limit (using Mapbox SpeedLimitView)
                if let speedLimit = state.speedLimit.value {
                    self.speedLimitView.signStandard = state.speedLimit.signStandard
                    self.speedLimitView.speedLimit = speedLimit
                    self.speedLimitView.isHidden = false
                    print("🚦 Speed limit: \(speedLimit) \(state.speedLimit.signStandard)")
                } else {
                    self.speedLimitView.isHidden = true
                }

                // Update road name
                if let roadName = state.roadName {
                    self.roadNameLabel.text = roadName.text
                    self.roadNameLabel.isHidden = false
                    print("🛣️ Road: \(roadName.text)")
                } else {
                    self.roadNameLabel.isHidden = true
                }
            }.store(in: &cancelables)

            // Subscribe to heading updates for aggressive bearing tracking
            subscribeToHeadingUpdates()
        }

        // Start traffic updates for real-time incident display
        startTrafficUpdates()

        print("🆓 Free-drive mode started - camera following user bearing")
    }

    // MARK: - Aggressive Camera Bearing Following

    private func subscribeToHeadingUpdates() {
        navigationProvider.mapboxNavigation.navigation().heading.sink { [weak self] heading in
            guard let self = self, !self.isNavigating else { return }
            self.updateCameraBearingContinuously(heading.trueHeading)
        }.store(in: &cancelables)

        print("🧭 Aggressive camera bearing tracking enabled")
    }

    private func updateCameraBearingContinuously(_ bearing: CLLocationDirection) {
        // Get current camera state
        let currentCamera = navigationMapView.mapView.cameraState

        // Create updated camera options with new bearing
        let cameraOptions = CameraOptions(
            center: currentCamera.center,
            padding: currentCamera.padding,
            zoom: currentCamera.zoom,
            bearing: bearing,  // Update bearing to match heading
            pitch: 45  // Maintain elevated pitch for better 3D view
        )

        // Smooth update with quick 300ms easing
        navigationMapView.mapView.camera.ease(
            to: cameraOptions,
            duration: 0.3,
            curve: .linear,
            completion: nil
        )
    }

    // MARK: - Traffic Updates

    private func startTrafficUpdates() {
        guard tomTomTrafficService != nil else { return }

        // Update immediately
        updateTrafficIncidents()

        // Then update every 60 seconds
        trafficUpdateTimer?.invalidate()
        trafficUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateTrafficIncidents()
        }

        print("🚦 Traffic updates started (60s interval)")
    }

    private func stopTrafficUpdates() {
        trafficUpdateTimer?.invalidate()
        trafficUpdateTimer = nil
        incidentAnnotationManager?.annotations = []
        print("🚦 Traffic updates stopped")
    }

    private func updateTrafficIncidents() {
        guard let trafficService = tomTomTrafficService else { return }

        // Get visible region bounds
        let visibleCoordinates = navigationMapView.mapView.mapboxMap.coordinateBounds(for: navigationMapView.mapView.bounds)

        let boundingBox = (
            minLat: visibleCoordinates.southwest.latitude,
            minLon: visibleCoordinates.southwest.longitude,
            maxLat: visibleCoordinates.northeast.latitude,
            maxLon: visibleCoordinates.northeast.longitude
        )

        trafficService.getTrafficIncidents(in: boundingBox) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let incidents):
                    self?.displayTrafficIncidents(incidents)
                case .failure(let error):
                    print("⚠️ Traffic incidents fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func displayTrafficIncidents(_ incidents: [TomTomTrafficService.TrafficIncident]) {
        guard let manager = incidentAnnotationManager else { return }

        // Create annotations for each incident
        var annotations: [PointAnnotation] = []

        for incident in incidents {
            var annotation = PointAnnotation(coordinate: incident.coordinate)

            // Set icon based on type
            let iconName: String
            switch incident.type {
            case 1: iconName = "exclamationmark.triangle.fill" // Accident
            case 2: iconName = "hammer.fill"                    // Roadwork
            case 3: iconName = "xmark.octagon.fill"            // Closure
            default: iconName = "exclamationmark.circle.fill"  // Other
            }

            annotation.iconImage = iconName

            // Color by severity
            let iconColor: UIColor
            switch incident.severity {
            case "Severe", "High": iconColor = .systemRed
            case "Medium": iconColor = .systemOrange
            default: iconColor = .systemYellow
            }

            annotation.iconColor = StyleColor(iconColor)
            annotation.iconSize = 1.2

            // Add text label
            annotation.textField = incident.description
            annotation.textColor = StyleColor(.white)
            annotation.textHaloColor = StyleColor(.black)
            annotation.textHaloWidth = 2
            annotation.textSize = 10
            annotation.textOffset = [0, -2]

            annotations.append(annotation)
        }

        manager.annotations = annotations

        if !incidents.isEmpty {
            print("🚦 Displaying \(incidents.count) traffic incidents on map")
        }
    }

    // MARK: - Route Preview UI

    private func setupRoutePreviewUI() {
        // Simple container with just Cancel and Start buttons
        // Mapbox NavigationMapView.showcase() handles route display on map
        routePreviewContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        routePreviewContainer.layer.cornerRadius = 16
        routePreviewContainer.layer.shadowColor = UIColor.black.cgColor
        routePreviewContainer.layer.shadowOpacity = 0.3
        routePreviewContainer.layer.shadowOffset = CGSize(width: 0, height: -4)
        routePreviewContainer.layer.shadowRadius = 8
        routePreviewContainer.translatesAutoresizingMaskIntoConstraints = false
        routePreviewContainer.isHidden = true
        view.addSubview(routePreviewContainer)

        // Cancel button
        cancelRouteButton.setTitle("Cancel", for: .normal)
        cancelRouteButton.backgroundColor = .systemGray5
        cancelRouteButton.setTitleColor(.label, for: .normal)
        cancelRouteButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelRouteButton.layer.cornerRadius = 12
        cancelRouteButton.translatesAutoresizingMaskIntoConstraints = false
        cancelRouteButton.addTarget(self, action: #selector(cancelAllRouting), for: .touchUpInside)
        routePreviewContainer.addSubview(cancelRouteButton)

        // Start navigation button
        startNavigationButton.setTitle("🚛 Start Navigation", for: .normal)
        startNavigationButton.backgroundColor = .systemBlue
        startNavigationButton.setTitleColor(.white, for: .normal)
        startNavigationButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        startNavigationButton.layer.cornerRadius = 12
        startNavigationButton.translatesAutoresizingMaskIntoConstraints = false
        startNavigationButton.addTarget(self, action: #selector(confirmStartNavigation), for: .touchUpInside)
        routePreviewContainer.addSubview(startNavigationButton)

        NSLayoutConstraint.activate([
            routePreviewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            routePreviewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            routePreviewContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            routePreviewContainer.heightAnchor.constraint(equalToConstant: 80),

            cancelRouteButton.topAnchor.constraint(equalTo: routePreviewContainer.topAnchor, constant: 16),
            cancelRouteButton.leadingAnchor.constraint(equalTo: routePreviewContainer.leadingAnchor, constant: 16),
            cancelRouteButton.widthAnchor.constraint(equalTo: routePreviewContainer.widthAnchor, multiplier: 0.3),
            cancelRouteButton.heightAnchor.constraint(equalToConstant: 50),

            startNavigationButton.topAnchor.constraint(equalTo: routePreviewContainer.topAnchor, constant: 16),
            startNavigationButton.trailingAnchor.constraint(equalTo: routePreviewContainer.trailingAnchor, constant: -16),
            startNavigationButton.leadingAnchor.constraint(equalTo: cancelRouteButton.trailingAnchor, constant: 12),
            startNavigationButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func showRoutePreview(for navigationRoutes: NavigationRoutes) {
        // Store routes
        currentNavigationRoutes = navigationRoutes

        // Use Mapbox NavigationMapView's showcase() method to display route
        navigationMapView.showcase(navigationRoutes, animated: true)

        // Show simple start navigation button
        routePreviewContainer.isHidden = false
        recenterButton.isHidden = true

        view.bringSubviewToFront(routePreviewContainer)

        let primaryRoute = navigationRoutes.mainRoute.route
        let distanceMiles = primaryRoute.distance * 0.000621371
        let durationMinutes = Int(primaryRoute.expectedTravelTime / 60)
        print("✅ Mapbox showcase(): Route displayed - \(String(format: "%.1f mi", distanceMiles)), \(durationMinutes) min")
        print("📍 +\(navigationRoutes.alternativeRoutes.count) alternative route(s) available")
    }

    // MARK: - Universal Route Cancellation

    /// Shared cleanup method called after navigation ends (either user-initiated or programmatic)
    private func cleanupAfterNavigation() {
        isNavigating = false

        // CRITICAL: Force dismiss NavigationViewController if still presented before setting to nil
        // This ensures the VC's UI (route banners, trip info) is actually removed from screen
        if let navVC = currentNavigationViewController {
            if navVC.presentingViewController != nil {
                print("⚠️ NavigationVC still presented - force dismissing")
                navVC.dismiss(animated: false)  // Force immediate dismissal
            }
        }

        currentNavigationViewController = nil
        currentNavigationRoutes = nil
        routePreviewContainer.isHidden = true

        // Ensure map is clean and we're back to free-drive
        navigationMapView.removeRoutes()
        navigationMapView.navigationCamera.stop()
        navigationMapView.navigationCamera.update(cameraState: .idle)

        // Re-enable puck
        navigationMapView.puckType = .puck2D(.navigationDefault)
        navigationMapView.mapView.location.options.puckBearingEnabled = true

        // Restart free-drive mode
        startFreeDriveMode()

        // Show free-drive UI elements
        panelController.view.isHidden = false
        recenterButton.isHidden = false
        settingsButton.isHidden = false

        // Recenter camera immediately
        recenterMap()

        print("❌ Navigation ended - reset to free-drive state")
    }

    /// Universal cancellation method that works for both route preview and active navigation
    @objc private func cancelAllRouting() {
        if let navVC = currentNavigationViewController {
            // CRITICAL: Only dismiss if VC is actually presented (prevents double-dismissal race condition)
            if navVC.presentingViewController != nil {
                navVC.dismiss(animated: true) { [weak self] in
                    self?.cleanupAfterNavigation()
                }
            } else {
                // VC already dismissed itself - just cleanup
                cleanupAfterNavigation()
            }
        } else {
            // If we're only previewing, use existing preview cancel logic
            cancelRoutePreview()
        }
    }

    @objc private func cancelRoutePreview() {
        // CRITICAL: Complete cleanup of NavigationMapView state
        navigationMapView.removeRoutes()

        // Stop navigation camera and explicitly return to idle state
        navigationMapView.navigationCamera.stop()
        navigationMapView.navigationCamera.update(cameraState: .idle)

        // CRITICAL FIX: Re-enable puck (showcase() may have modified it)
        navigationMapView.puckType = .puck2D(.navigationDefault)
        navigationMapView.mapView.location.options.puckBearingEnabled = true

        // Clear stored route data
        currentNavigationRoutes = nil

        // Hide route preview UI
        routePreviewContainer.isHidden = true

        // Show free-drive UI elements
        panelController.view.isHidden = false
        recenterButton.isHidden = false
        settingsButton.isHidden = false

        // CRITICAL FIX: Restart free-drive mode to ensure we're not stuck in route mode
        startFreeDriveMode()

        // Recenter camera immediately to ensure 3D follow mode is restored
        recenterMap()

        print("❌ Route preview canceled - fully reset to free-drive state")
    }

    @objc private func confirmStartNavigation() {
        guard let routes = currentNavigationRoutes else {
            print("⚠️ No routes available to start navigation")
            return
        }

        // Hide route preview
        routePreviewContainer.isHidden = true

        // Start navigation with selected routes
        startNavigation(with: routes)
    }

    private func calculateRoute(to destination: CLLocationCoordinate2D) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location available")
            return
        }

        print("🚛 Calculating TRUCK route from \(userLocation) to \(destination)")
        print("🚛 Truck params: \(truckHeight.value)m height, \(truckWidth.value)m width, \(truckWeight.value)t weight")

        // Calculate distance to determine routing strategy
        let distance = userLocation.distance(to: destination)

        // Strategy: Use TomTom for long routes (>50km) or if available, otherwise Mapbox
        if let tomTomService = tomTomRoutingService, distance > 50000 {
            print("🚛 Using TomTom Routing API for long-distance truck route (\(Int(distance/1000))km)")
            calculateTomTomRoute(from: userLocation, to: destination, using: tomTomService)
        } else {
            print("🚛 Using Mapbox Routing API")
            calculateMapboxRoute(from: userLocation, to: destination)
        }
    }

    // MARK: - TomTom Routing

    private func calculateTomTomRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        using service: TomTomRoutingService
    ) {
        // Build truck parameters from settings
        var truckParams = TruckParameters()
        truckParams.height = truckHeight.value
        truckParams.width = truckWidth.value
        truckParams.weight = Int(truckWeight.value * 1000) // Convert metric tons to kg
        truckParams.commercialVehicle = true
        truckParams.avoidUnpavedRoads = true

        // Calculate route with TomTom
        service.calculateRoute(
            from: origin,
            to: destination,
            truckParams: truckParams
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    guard let tomTomRoute = response.routes.first else {
                        print("⚠️ No routes in TomTom response, falling back to Mapbox")
                        self?.calculateMapboxRoute(from: origin, to: destination)
                        return
                    }

                    let distanceMiles = Double(tomTomRoute.summary.lengthInMeters) * 0.000621371
                    let durationMinutes = tomTomRoute.summary.travelTimeInSeconds / 60
                    print("✅ TomTom route: \(String(format: "%.1f mi", distanceMiles)), \(durationMinutes) min")

                    // Display TomTom route on map (visual only, then fallback to Mapbox for navigation)
                    self?.displayTomTomRouteAndUseMapboxForNavigation(tomTomRoute, from: origin, to: destination)

                case .failure(let error):
                    print("❌ TomTom routing failed: \(error.localizedDescription)")
                    print("🔄 Falling back to Mapbox routing")
                    self?.calculateMapboxRoute(from: origin, to: destination)
                }
            }
        }
    }

    private func displayTomTomRouteAndUseMapboxForNavigation(
        _ tomTomRoute: TomTomRoute,
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) {
        // For now, use Mapbox for actual navigation since NavigationViewController requires NavigationRoutes
        // TomTom route is validated and available, but we'll use Mapbox navigation system
        print("🔄 Using Mapbox for turn-by-turn navigation (TomTom route validated)")
        calculateMapboxRoute(from: origin, to: destination)
    }

    // MARK: - Mapbox Routing

    private func calculateMapboxRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) {
        // Configure truck-specific route options
        let routeOptions = configureTruckRouteOptions(from: origin, to: destination)

        // Calculate route using Navigation Provider (v3 async API)
        let request = mapboxNavigation.routingProvider().calculateRoutes(options: routeOptions)

        Task { @MainActor in
            switch await request.result {
            case .success(let navigationRoutes):
                print("✅ Mapbox truck route calculated successfully")
                print("🚛 Route respects truck restrictions!")

                // Show route preview with alternatives before starting navigation
                showRoutePreview(for: navigationRoutes)

            case .failure(let error):
                print("❌ Route calculation failed: \(error)")

                let alert = UIAlertController(
                    title: "Route Error",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }

    private func startNavigation(with navigationRoutes: NavigationRoutes) {
        // Set isNavigating first to prevent locationMatching from updating UI
        isNavigating = true

        // Clear search annotations before starting navigation
        clearSearchAnnotations()

        // Pause free-drive session before starting turn-by-turn navigation
        if isFreeDriveActive {
            navigationProvider.tripSession().pauseFreeDrive()
            isFreeDriveActive = false
            print("⏸️ Free-drive mode paused for turn-by-turn navigation")
        }

        // Hide free-drive UI during active navigation
        speedLimitView.isHidden = true
        roadNameLabel.isHidden = true
        panelController.view.isHidden = true
        recenterButton.isHidden = true
        settingsButton.isHidden = true
        routePreviewContainer.isHidden = true  // Hide our custom Cancel/Start buttons

        // Configure navigation options using the navigation provider
        let navigationOptions = NavigationOptions(
            mapboxNavigation: mapboxNavigation,
            voiceController: navigationProvider.routeVoiceController,
            eventsManager: navigationProvider.eventsManager()
        )

        // Create Mapbox NavigationViewController (drop-in UI component)
        let navigationViewController = NavigationViewController(
            navigationRoutes: navigationRoutes,
            navigationOptions: navigationOptions
        )
        navigationViewController.delegate = self
        navigationViewController.modalPresentationStyle = .fullScreen

        // Present Mapbox's premium navigation UI
        present(navigationViewController, animated: true) {
            print("🧭 Truck navigation started with Mapbox NavigationViewController v3")
            print("🚛 Voice guidance, 3D camera, and speed limits enabled automatically")
        }

        currentNavigationViewController = navigationViewController
    }

    // Note: Navigation UI, route drawing, voice guidance, speed limits, etc.
    // are all handled automatically by Mapbox NavigationViewController
}

// MARK: - SearchControllerDelegate

extension MapViewController: SearchControllerDelegate {
    func searchResultSelected(_ searchResult: SearchResult) {
        // User selected a search result from MapboxSearchUI
        let coordinate = searchResult.coordinate

        print("📍 Selected destination: \(searchResult.name)")

        // Dismiss search controller
        searchController.dismiss(animated: true)

        // Clear any category search annotations
        clearSearchAnnotations()

        // Calculate route to selected destination
        calculateRoute(to: coordinate)
    }

    func categorySearchResultsReceived(category: SearchCategory, results: [SearchResult]) {
        print("📂 Category search: \(category.name) - \(results.count) results nearby")

        if results.isEmpty {
            print("⚠️ No \(category.name) found nearby")
            return
        }

        // Store search results
        currentSearchResults = results

        // Display results as map annotations
        displaySearchResultsAsAnnotations(results: results, category: category.name)

        print("✅ Displaying \(results.count) \(category.name) locations on map")
    }

    private func displaySearchResultsAsAnnotations(results: [SearchResult], category: String) {
        // Clear previous annotations
        clearSearchAnnotations()

        // Create annotations for each search result
        var annotations: [PointAnnotation] = []

        for result in results {
            var annotation = PointAnnotation(coordinate: result.coordinate)
            annotation.textField = result.name
            annotation.textColor = StyleColor(.label)
            annotation.textHaloColor = StyleColor(.systemBackground)
            annotation.textHaloWidth = 2
            annotation.textOffset = [0, -1.5]
            annotation.textSize = 12

            // Use SF Symbol for pin
            annotation.iconImage = "mappin.circle.fill"
            annotation.iconSize = 1.5

            annotations.append(annotation)
        }

        // Add annotations to map
        pointAnnotationManager.annotations = annotations

        // Fit camera to show all annotations
        fitCameraToAnnotations(coordinates: results.map { $0.coordinate })

        print("📍 Added \(annotations.count) \(category) pins to map")
    }

    private func fitCameraToAnnotations(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }

        // If single coordinate, just center on it
        if coordinates.count == 1 {
            let cameraOptions = CameraOptions(
                center: coordinates[0],
                zoom: 15,
                pitch: 0
            )
            navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 1.5, curve: .easeInOut, completion: nil)
            return
        }

        // Calculate bounding box for multiple coordinates
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else { return }

        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        // Calculate appropriate zoom level based on span
        let latSpan = maxLat - minLat
        let lonSpan = maxLon - minLon
        let maxSpan = max(latSpan, lonSpan)

        // Simple zoom calculation (adjust as needed)
        let zoom = max(10.0, 15.0 - log2(maxSpan * 100))

        let cameraOptions = CameraOptions(
            center: center,
            padding: UIEdgeInsets(top: 100, left: 50, bottom: 200, right: 50),
            zoom: zoom,
            pitch: 0
        )

        navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 1.5, curve: .easeInOut, completion: nil)
    }

    private func clearSearchAnnotations() {
        pointAnnotationManager.annotations = []
        currentSearchResults = []
        print("🗑️ Cleared search annotations")
    }

    func userFavoriteSelected(_ userFavorite: FavoriteRecord) {
        // Handle favorite selection if needed
        let coordinate = userFavorite.coordinate
        print("⭐ Selected favorite: \(userFavorite.name)")

        searchController.dismiss(animated: true)
        calculateRoute(to: coordinate)
    }
}

// MARK: - NavigationViewControllerDelegate

extension MapViewController: NavigationViewControllerDelegate {
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        // CRITICAL: This delegate is called AFTER the NavigationViewController has already dismissed itself
        // Do NOT call dismiss() here - it will cause a double-dismissal race condition

        print(canceled ? "🛑 Navigation canceled - returning to free-drive" : "🎯 Navigation completed - returning to free-drive")

        // NavigationViewController already dismissed itself - just cleanup
        cleanupAfterNavigation()

        // Note: speedLimitView and roadNameLabel visibility is managed by locationMatching subscription
        // They will automatically show when data is available
    }

    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        print("🎉 Arrived at destination!")

        // Return true to allow NavigationViewController to auto-dismiss
        // It will call navigationViewControllerDidDismiss after dismissing
        // DO NOT manually call dismiss() here - causes double-dismissal
        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension MapViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Update search proximity with new location
        configureSearchProximity()

        // Update weather every 10 minutes to avoid API rate limits
        let shouldUpdateWeather: Bool
        if let lastUpdate = lastWeatherUpdateTime {
            shouldUpdateWeather = Date().timeIntervalSince(lastUpdate) > 600 // 10 minutes
        } else {
            shouldUpdateWeather = true // First time
        }

        if shouldUpdateWeather {
            fetchWeather(for: location.coordinate)
            lastWeatherUpdateTime = Date()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            lastBearing = newHeading.trueHeading
        }
    }
}

// MARK: - AnnotationInteractionDelegate

extension MapViewController: AnnotationInteractionDelegate {
    func annotationManager(_ manager: AnnotationManager, didDetectTappedAnnotations annotations: [Annotation]) {
        guard let annotation = annotations.first as? PointAnnotation else { return }

        // Find the search result for this annotation
        if let index = currentSearchResults.firstIndex(where: { result in
            result.coordinate.latitude == annotation.point.coordinates.latitude &&
            result.coordinate.longitude == annotation.point.coordinates.longitude
        }) {
            let searchResult = currentSearchResults[index]
            print("📍 Tapped annotation: \(searchResult.name)")

            // Calculate route to selected location
            calculateRoute(to: searchResult.coordinate)

            // Clear annotations after selection
            clearSearchAnnotations()
        }
    }
}

extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }
}
