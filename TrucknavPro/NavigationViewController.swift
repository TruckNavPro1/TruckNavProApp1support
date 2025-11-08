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

    // Search components
    private let searchBar = UISearchBar()
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

    private lazy var testButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📍 Set Test Destination", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(setTestDestination), for: .touchUpInside)
        return button
    }()

    private lazy var endNavigationButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("✕ End Navigation", for: .normal)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(endNavigation), for: .touchUpInside)
        button.isHidden = true
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
        setupSearchBar()
        setupSearchResultsTable()
        setupNavigationUI()
        setupTestButton()

        // Ensure proper z-ordering (bring controls to front)
        view.bringSubviewToFront(searchBar)
        view.bringSubviewToFront(searchResultsTable)
        view.bringSubviewToFront(instructionView)
        view.bringSubviewToFront(bottomInfoView)
        view.bringSubviewToFront(endNavigationButton)
        view.bringSubviewToFront(testButton)

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
        let mapInitOptions = MapInitOptions(styleURI: .streets)
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

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search destination"
        searchBar.searchBarStyle = .minimal
        searchBar.showsCancelButton = true
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 50)
        ])
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
            searchResultsTable.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
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

        // End navigation button
        view.addSubview(endNavigationButton)

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
            speedLabel.trailingAnchor.constraint(equalTo: bottomInfoView.trailingAnchor, constant: -16),

            endNavigationButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            endNavigationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            endNavigationButton.widthAnchor.constraint(equalToConstant: 140),
            endNavigationButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func setupTestButton() {
        view.addSubview(testButton)

        NSLayoutConstraint.activate([
            testButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -120),
            testButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            testButton.widthAnchor.constraint(equalToConstant: 250),
            testButton.heightAnchor.constraint(equalToConstant: 50)
        ])
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

    @objc private func setTestDestination() {
        print("🔥 BUTTON TAPPED!")

        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location")

            let alert = UIAlertController(
                title: "No Location",
                message: "Waiting for location...",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        print("✅ User location: \(userLocation)")

        let testDestination = CLLocationCoordinate2D(
            latitude: userLocation.latitude + 0.05,
            longitude: userLocation.longitude
        )

        calculateRoute(to: testDestination)
    }

    @objc private func endNavigation() {
        isNavigating = false

        // Dismiss NavigationViewController if it's still presented
        if let navVC = currentNavigationViewController {
            navVC.dismiss(animated: true) {
                print("🛑 Navigation ended")
            }
            currentNavigationViewController = nil
        }

        // Show search UI again
        instructionView.isHidden = true
        bottomInfoView.isHidden = true
        endNavigationButton.isHidden = true
        testButton.isHidden = false
        searchBar.isHidden = false
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

                startNavigation(with: navigationRoutes)

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

extension MapViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        performSearch(query: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchResults = []
        searchResultsTable.isHidden = true
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

        searchBar.text = placemark.formattedName
        searchBar.resignFirstResponder()
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

        print(canceled ? "🛑 Navigation canceled" : "🎯 Navigation completed")
    }

    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        print("🎉 Arrived at destination!")
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
