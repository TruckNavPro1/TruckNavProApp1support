//
//  NavigationViewController.swift
//  TruckNavPro
//

import UIKit
import MapboxMaps
import MapboxGeocoder
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import CoreLocation
import Combine

class MapViewController: UIViewController {

    private var mapView: MapView!
    private let locationManager = CLLocationManager()
    private var cancelables = Set<AnyCancelable>()
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
    private var currentNavigationRoutes: NavigationRoutes?

    // Free-drive mode UI
    private let speedLimitView = UILabel()
    private let roadNameLabel = UILabel()

    // Route preview UI
    private let routePreviewContainer = UIView()
    private let startNavigationButton = UIButton(type: .system)
    private let routeInfoStack = UIStackView()

    // Search components
    private let searchContainer = UIView()
    private let searchTextField = UITextField()
    private let searchResultsTable = UITableView()
    private var searchResults: [GeocodedPlacemark] = []
    private var geocoder: Geocoder!
    private var currentGeocodeTask: URLSessionDataTask?

    // Navigation UI
    private let instructionView = NavigationInstructionView()
    private let bottomInfoView = UIView()
    private let etaLabel = UILabel()
    private let distanceLabel = UILabel()
    private let speedLabel = UILabel()

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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize Mapbox Navigation Provider (v3)
        let coreConfig = CoreConfig()
        navigationProvider = MapboxNavigationProvider(coreConfig: coreConfig)
        mapboxNavigation = navigationProvider.mapboxNavigation

        setupLocationManager()
        setupMapView()
        setupSearchUI()
        setupSearchResultsTable()
        setupNavigationUI()
        setupFreeDriveUI()
        setupRoutePreviewUI()
        setupRecenterButton()

        // Ensure proper z-ordering (bring controls to front)
        view.bringSubviewToFront(searchContainer)
        view.bringSubviewToFront(searchResultsTable)
        view.bringSubviewToFront(instructionView)
        view.bringSubviewToFront(bottomInfoView)
        view.bringSubviewToFront(recenterButton)
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
        // Use Mapbox Standard style for modern look and feel
        let mapInitOptions = MapInitOptions(styleURI: .standard)
        mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)

        // Initialize Geocoder with Mapbox access token
        guard let mapboxToken = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String else {
            fatalError("Mapbox access token not found in Info.plist")
        }
        geocoder = Geocoder(accessToken: mapboxToken)

        mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
            self?.configurePuck()
            self?.configureNavigationCamera()
            self?.enable3DBuildings()
            print("✅ Free-drive navigation active")
        }.store(in: &cancelables)
    }

    private func configurePuck() {
        var puckConfig = Puck2DConfiguration()
        puckConfig.showsAccuracyRing = false
        puckConfig.pulsing = .default
        mapView.location.options.puckType = .puck2D(puckConfig)
        mapView.location.options.puckBearingEnabled = true
    }

    private func configureNavigationCamera() {
        let pitch: CGFloat = 60
        let zoom: CGFloat = 17

        mapView.location.onLocationChange.observe { [weak self] locations in
            guard let self = self, let location = locations.last else { return }

            var bearing = self.lastBearing
            if let clLocation = location as? CLLocation, clLocation.course >= 0 {
                bearing = clLocation.course
                self.lastBearing = bearing
            }

            let cameraOptions = CameraOptions(
                center: location.coordinate,
                padding: UIEdgeInsets(top: 0, left: 0, bottom: self.view.bounds.height * 0.4, right: 0),
                zoom: zoom,
                bearing: bearing,
                pitch: pitch
            )

            self.mapView.camera.ease(to: cameraOptions, duration: 1.0)

            // Free-drive mode camera tracking
            // When NavigationViewController is active, it handles its own camera
        }.store(in: &self.cancelables)
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

            try mapView.mapboxMap.addLayer(layer)
            print("✅ 3D buildings enabled")
        } catch {
            print("⚠️ 3D buildings error: \(error)")
        }
    }

    private func setupSearchUI() {
        // Search container with shadow
        searchContainer.backgroundColor = .systemBackground
        searchContainer.layer.cornerRadius = 12
        searchContainer.layer.shadowColor = UIColor.black.cgColor
        searchContainer.layer.shadowOpacity = 0.15
        searchContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        searchContainer.layer.shadowRadius = 8
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)

        // Search icon
        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = .secondaryLabel
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchIcon)

        // Search text field
        searchTextField.placeholder = "Where to?"
        searchTextField.font = .systemFont(ofSize: 16)
        searchTextField.borderStyle = .none
        searchTextField.returnKeyType = .search
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextDidChange), for: .editingChanged)
        searchContainer.addSubview(searchTextField)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 56),

            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),

            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 12),
            searchTextField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -16),
            searchTextField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor)
        ])
    }

    @objc private func searchTextDidChange() {
        performSearch(query: searchTextField.text ?? "")
    }

    private func setupSearchResultsTable() {
        searchResultsTable.delegate = self
        searchResultsTable.dataSource = self
        searchResultsTable.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        searchResultsTable.translatesAutoresizingMaskIntoConstraints = false
        searchResultsTable.isHidden = true
        searchResultsTable.layer.cornerRadius = 8
        searchResultsTable.layer.shadowColor = UIColor.black.cgColor
        searchResultsTable.layer.shadowOpacity = 0.2
        searchResultsTable.layer.shadowOffset = CGSize(width: 0, height: 2)
        searchResultsTable.layer.shadowRadius = 4
        view.addSubview(searchResultsTable)

        NSLayoutConstraint.activate([
            searchResultsTable.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            searchResultsTable.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchResultsTable.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchResultsTable.heightAnchor.constraint(equalToConstant: 300)
        ])
    }

    private func setupNavigationUI() {
        // Instruction view
        instructionView.translatesAutoresizingMaskIntoConstraints = false
        instructionView.isHidden = true
        view.addSubview(instructionView)

        // Bottom info view
        bottomInfoView.backgroundColor = .systemBackground
        bottomInfoView.layer.cornerRadius = 12
        bottomInfoView.layer.shadowColor = UIColor.black.cgColor
        bottomInfoView.layer.shadowOpacity = 0.2
        bottomInfoView.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomInfoView.layer.shadowRadius = 8
        bottomInfoView.translatesAutoresizingMaskIntoConstraints = false
        bottomInfoView.isHidden = true
        view.addSubview(bottomInfoView)

        // ETA Label
        etaLabel.font = .systemFont(ofSize: 16, weight: .medium)
        etaLabel.textColor = .label
        etaLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomInfoView.addSubview(etaLabel)

        // Distance Label
        distanceLabel.font = .systemFont(ofSize: 16, weight: .medium)
        distanceLabel.textColor = .label
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomInfoView.addSubview(distanceLabel)

        // Speed Label
        speedLabel.font = .systemFont(ofSize: 16, weight: .medium)
        speedLabel.textColor = .label
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomInfoView.addSubview(speedLabel)

        NSLayoutConstraint.activate([
            instructionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            instructionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            instructionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            instructionView.heightAnchor.constraint(equalToConstant: 120),

            bottomInfoView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomInfoView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomInfoView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            bottomInfoView.heightAnchor.constraint(equalToConstant: 80),

            etaLabel.topAnchor.constraint(equalTo: bottomInfoView.topAnchor, constant: 12),
            etaLabel.leadingAnchor.constraint(equalTo: bottomInfoView.leadingAnchor, constant: 16),

            distanceLabel.topAnchor.constraint(equalTo: etaLabel.bottomAnchor, constant: 8),
            distanceLabel.leadingAnchor.constraint(equalTo: bottomInfoView.leadingAnchor, constant: 16),

            speedLabel.topAnchor.constraint(equalTo: bottomInfoView.topAnchor, constant: 12),
            speedLabel.trailingAnchor.constraint(equalTo: bottomInfoView.trailingAnchor, constant: -16)
        ])
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
        guard let userLocation = locationManager.location?.coordinate else { return }

        let cameraOptions = CameraOptions(
            center: userLocation,
            padding: UIEdgeInsets(top: 0, left: 0, bottom: view.bounds.height * 0.4, right: 0),
            zoom: 17,
            bearing: lastBearing,
            pitch: 60
        )

        mapView.camera.ease(to: cameraOptions, duration: 0.5)
        print("📍 Map recentered to current location")
    }

    // MARK: - Free-Drive Mode UI

    private func setupFreeDriveUI() {
        // Speed Limit View
        speedLimitView.font = .boldSystemFont(ofSize: 24)
        speedLimitView.textColor = .white
        speedLimitView.backgroundColor = .systemRed
        speedLimitView.textAlignment = .center
        speedLimitView.layer.cornerRadius = 8
        speedLimitView.layer.borderWidth = 3
        speedLimitView.layer.borderColor = UIColor.white.cgColor
        speedLimitView.clipsToBounds = true
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
        // Note: Free-drive mode will be enhanced in a future update
        // For now, basic location tracking is provided through location manager
        print("🆓 Free-drive mode - using basic location tracking")

        // Speed limit and road name features will be added when
        // the correct v3 API is confirmed for passive navigation
    }

    // MARK: - Route Preview UI

    private func setupRoutePreviewUI() {
        // Container for route preview
        routePreviewContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        routePreviewContainer.layer.cornerRadius = 16
        routePreviewContainer.layer.shadowColor = UIColor.black.cgColor
        routePreviewContainer.layer.shadowOpacity = 0.3
        routePreviewContainer.layer.shadowOffset = CGSize(width: 0, height: -4)
        routePreviewContainer.layer.shadowRadius = 8
        routePreviewContainer.translatesAutoresizingMaskIntoConstraints = false
        routePreviewContainer.isHidden = true
        view.addSubview(routePreviewContainer)

        // Route info stack
        routeInfoStack.axis = .vertical
        routeInfoStack.spacing = 12
        routeInfoStack.translatesAutoresizingMaskIntoConstraints = false
        routePreviewContainer.addSubview(routeInfoStack)

        // Start navigation button
        startNavigationButton.setTitle("🚛 Start Truck Navigation", for: .normal)
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
            routePreviewContainer.heightAnchor.constraint(equalToConstant: 180),

            routeInfoStack.topAnchor.constraint(equalTo: routePreviewContainer.topAnchor, constant: 20),
            routeInfoStack.leadingAnchor.constraint(equalTo: routePreviewContainer.leadingAnchor, constant: 20),
            routeInfoStack.trailingAnchor.constraint(equalTo: routePreviewContainer.trailingAnchor, constant: -20),

            startNavigationButton.topAnchor.constraint(equalTo: routeInfoStack.bottomAnchor, constant: 16),
            startNavigationButton.leadingAnchor.constraint(equalTo: routePreviewContainer.leadingAnchor, constant: 20),
            startNavigationButton.trailingAnchor.constraint(equalTo: routePreviewContainer.trailingAnchor, constant: -20),
            startNavigationButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func showRoutePreview(for navigationRoutes: NavigationRoutes) {
        // Store routes
        currentNavigationRoutes = navigationRoutes

        // Clear previous route info
        routeInfoStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Get primary route
        let primaryRoute = navigationRoutes.mainRoute.route
        guard primaryRoute.legs.count > 0 else {
            print("⚠️ No primary route found")
            return
        }

        // Create route info labels
        let titleLabel = UILabel()
        titleLabel.text = "🚛 Truck-Safe Route"
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textColor = .label

        let distanceLabel = UILabel()
        let distanceMiles = primaryRoute.distance * 0.000621371
        distanceLabel.text = String(format: "📏 Distance: %.1f mi", distanceMiles)
        distanceLabel.font = .systemFont(ofSize: 16)
        distanceLabel.textColor = .secondaryLabel

        let durationLabel = UILabel()
        let durationMinutes = Int(primaryRoute.expectedTravelTime / 60)
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            durationLabel.text = String(format: "⏱️ Time: %dh %dm", hours, minutes)
        } else {
            durationLabel.text = String(format: "⏱️ Time: %dm", minutes)
        }
        durationLabel.font = .systemFont(ofSize: 16)
        durationLabel.textColor = .secondaryLabel

        // Check for alternative routes
        let alternativesLabel = UILabel()
        if navigationRoutes.alternativeRoutes.count > 0 {
            alternativesLabel.text = "📍 +\(navigationRoutes.alternativeRoutes.count) alternative route(s) available"
            alternativesLabel.font = .systemFont(ofSize: 14, weight: .medium)
            alternativesLabel.textColor = .systemBlue
        }

        routeInfoStack.addArrangedSubview(titleLabel)
        routeInfoStack.addArrangedSubview(distanceLabel)
        routeInfoStack.addArrangedSubview(durationLabel)
        if navigationRoutes.alternativeRoutes.count > 0 {
            routeInfoStack.addArrangedSubview(alternativesLabel)
        }

        // Show preview UI and hide other UI
        routePreviewContainer.isHidden = false
        searchContainer.isHidden = true
        recenterButton.isHidden = true
        speedLimitView.isHidden = true
        roadNameLabel.isHidden = true

        view.bringSubviewToFront(routePreviewContainer)

        print("📍 Route preview displayed with \(navigationRoutes.alternativeRoutes.count) alternatives")
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

    private func performSearch(query: String) {
        // Cancel previous search
        currentGeocodeTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            searchResultsTable.isHidden = true
            return
        }

        let options = ForwardGeocodeOptions(query: query)
        options.focalLocation = locationManager.location
        options.maximumResultCount = 5

        currentGeocodeTask = geocoder.geocode(options) { [weak self] (placemarks, attribution, error) in
            guard let self = self else { return }

            if let error = error {
                // Don't log cancelled tasks as errors
                if (error as NSError).code != NSURLErrorCancelled {
                    print("❌ Geocoding error: \(error)")
                }
                return
            }

            guard let placemarks = placemarks, !placemarks.isEmpty else {
                print("⚠️ No results found")
                DispatchQueue.main.async {
                    self.searchResults = []
                    self.searchResultsTable.reloadData()
                }
                return
            }

            DispatchQueue.main.async {
                self.searchResults = placemarks
                self.searchResultsTable.reloadData()
                self.searchResultsTable.isHidden = false
            }
        }
    }


    private func calculateRoute(to destination: CLLocationCoordinate2D) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location available")
            return
        }

        print("🚛 Calculating TRUCK route from \(userLocation) to \(destination)")
        print("🚛 Truck params: \(truckHeight.value)m height, \(truckWidth.value)m width, \(truckWeight.value)t weight")

        // Configure truck-specific route options
        let routeOptions = configureTruckRouteOptions(from: userLocation, to: destination)

        // Calculate route using Navigation Provider (v3 async API)
        let request = mapboxNavigation.routingProvider().calculateRoutes(options: routeOptions)

        Task { @MainActor in
            switch await request.result {
            case .success(let navigationRoutes):
                print("✅ Truck route calculated successfully")
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
        isNavigating = true

        // Hide free-drive UI during active navigation
        speedLimitView.isHidden = true
        roadNameLabel.isHidden = true

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

extension MapViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Show search results table when user starts typing
    }
}

extension MapViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let placemark = searchResults[indexPath.row]

        cell.textLabel?.text = placemark.formattedName
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.font = .systemFont(ofSize: 14)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let placemark = searchResults[indexPath.row]

        guard let coordinate = placemark.location?.coordinate else { return }

        searchTextField.text = placemark.formattedName
        searchTextField.resignFirstResponder()
        searchResultsTable.isHidden = true

        calculateRoute(to: coordinate)
    }
}

// MARK: - NavigationViewControllerDelegate

extension MapViewController: NavigationViewControllerDelegate {
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        // User dismissed navigation (either by arriving or canceling)
        isNavigating = false
        currentNavigationViewController = nil
        currentNavigationRoutes = nil

        // Restart free-drive mode after navigation ends
        startFreeDriveMode()

        // Show free-drive UI elements
        speedLimitView.isHidden = false
        roadNameLabel.isHidden = false

        print(canceled ? "🛑 Navigation canceled - returning to free-drive" : "🎯 Navigation completed - returning to free-drive")
    }

    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        print("🎉 Arrived at destination!")

        // Automatically dismiss navigation after arrival
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            navigationViewController.dismiss(animated: true)
        }

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

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            lastBearing = newHeading.trueHeading
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
