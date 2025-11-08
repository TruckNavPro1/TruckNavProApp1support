//
//  NavigationViewController.swift
//  TruckNavPro
//

import UIKit
import MapboxMaps
import MapboxGeocoder
import CoreLocation
import Combine

class NavigationViewController: UIViewController {

    private var mapView: MapView!
    private let locationManager = CLLocationManager()
    private var cancelables = Set<AnyCancelable>()
    private var lastBearing: CLLocationDirection = 0

    // TomTom Routing
    private var tomtomService: TomTomRoutingService!

    // Standard US Semi-Trailer Parameters
    private var truckParameters = TruckParameters(
        weight: 36287,      // 80,000 lbs = 36,287 kg (US legal limit)
        axleWeight: 15422,  // 34,000 lbs per axle group
        length: 16.15,      // 53 ft trailer = 16.15 meters
        width: 2.44,        // 8 ft = 2.44 meters
        height: 4.11,       // 13'6" = 4.11 meters (standard semi height)
        commercialVehicle: true,
        loadType: nil       // Set to enable hazmat restrictions
    )

    // Navigation state
    private var currentRoute: TomTomRoute?
    private var currentRouteCoordinates: [CLLocationCoordinate2D] = []
    private var currentStepIndex: Int = 0
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

        // Uncomment to enable hazmat restrictions
        // enableHazmatMode()
    }

    // MARK: - Truck Configuration Helpers

    /// Enable hazmat mode: avoids tunnels, enables hazmat class
    private func enableHazmatMode(hazmatClasses: [String] = ["USHazmatClass2"]) {
        truckParameters.loadType = hazmatClasses
        truckParameters.avoidTunnels = true
        print("🚨 HAZMAT MODE ENABLED - Avoiding tunnels, hazmat class: \(hazmatClasses)")
    }

    /// Avoid tolls for cost optimization
    private func enableTollAvoidance() {
        truckParameters.avoidTolls = true
        print("💰 TOLL AVOIDANCE ENABLED")
    }

    /// Avoid ferries (for time-sensitive loads)
    private func enableFerryAvoidance() {
        truckParameters.avoidFerries = true
        print("⛴️ FERRY AVOIDANCE ENABLED")
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
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

        // Initialize TomTom Routing with API key
        guard let tomtomKey = Bundle.main.object(forInfoDictionaryKey: "TomTomAPIKey") as? String else {
            fatalError("TomTom API key not found in Info.plist")
        }
        tomtomService = TomTomRoutingService(apiKey: tomtomKey)

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

            // Update navigation if active
            if self.isNavigating {
                self.updateNavigationProgress(userLocation: location.coordinate)
            }
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
        currentRoute = nil
        currentStepIndex = 0

        instructionView.isHidden = true
        bottomInfoView.isHidden = true
        endNavigationButton.isHidden = true
        testButton.isHidden = false
        searchBar.isHidden = false

        // Remove route line
        do {
            try mapView.mapboxMap.removeLayer(withId: "route-layer")
            try mapView.mapboxMap.removeSource(withId: "route-source")
            print("✅ Route line removed from map")
        } catch {
            print("⚠️ Could not remove route line: \(error.localizedDescription)")
        }

        print("🛑 Navigation ended")
    }

    private func calculateRoute(to destination: CLLocationCoordinate2D) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location available")
            return
        }

        print("🚛 Calculating TRUCK route from \(userLocation) to \(destination)")
        print("🚛 Truck params: \(truckParameters.weight ?? 0)kg, \(truckParameters.height ?? 0)m height")

        // Use TomTom for truck routing
        tomtomService.calculateRoute(
            from: userLocation,
            to: destination,
            truckParams: truckParameters
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                guard let route = response.routes.first else {
                    print("⚠️ No route found")
                    DispatchQueue.main.async {
                        let alert = UIAlertController(
                            title: "No Route",
                            message: "No truck route found for this destination",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                    return
                }

                print("✅ Truck route calculated: \(route.distance)m, \(route.travelTime)s")
                print("🚛 Route respects truck restrictions!")

                DispatchQueue.main.async {
                    self.startNavigation(with: route)
                }

            case .failure(let error):
                print("❌ Route calculation failed: \(error)")

                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Route Error",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func startNavigation(with route: TomTomRoute) {
        currentRoute = route
        currentRouteCoordinates = route.toCoordinates()
        currentStepIndex = 0
        isNavigating = true

        drawRoute(route)

        // Hide search UI, show navigation UI
        searchBar.isHidden = true
        testButton.isHidden = true
        instructionView.isHidden = false
        bottomInfoView.isHidden = false
        endNavigationButton.isHidden = false

        updateInstructions()

        print("🧭 Truck navigation started")
    }

    private func updateNavigationProgress(userLocation: CLLocationCoordinate2D) {
        guard let route = currentRoute,
              let destinationCoord = currentRouteCoordinates.last else {
            return
        }

        // Check distance to destination
        let distanceToDestination = userLocation.distance(to: destinationCoord)

        // If within 50 meters of destination, mark as arrived
        if distanceToDestination < 50 {
            arrivedAtDestination()
            return
        }

        updateBottomInfo()
    }

    private func updateInstructions() {
        guard let route = currentRoute else { return }

        // Simplified instructions for now
        let distance = formatDistance(route.distance)
        let instruction = "Follow the truck route"

        instructionView.configure(
            distance: distance,
            instruction: instruction,
            roadName: "Truck-safe route",
            maneuverType: "straight"
        )
    }

    private func updateBottomInfo() {
        guard let route = currentRoute,
              let location = locationManager.location else {
            return
        }

        // Calculate ETA
        let eta = Date().addingTimeInterval(route.travelTime)
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        etaLabel.text = "ETA: \(formatter.string(from: eta))"
        distanceLabel.text = "Distance: \(formatDistance(route.distance))"

        // Current speed
        let speed = location.speed >= 0 ? location.speed * 2.23694 : 0 // m/s to mph
        speedLabel.text = String(format: "%.0f mph", speed)
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            let miles = meters * 0.000621371
            return String(format: "%.1f mi", miles)
        }
    }

    private func arrivedAtDestination() {
        isNavigating = false

        let alert = UIAlertController(
            title: "🎉 You've Arrived!",
            message: "You have reached your destination",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.endNavigation()
        })
        present(alert, animated: true)

        print("🎯 Arrived at destination")
    }

    private func drawRoute(_ route: TomTomRoute) {
        let coordinates = route.toCoordinates()
        print("🚛 Truck route has \(coordinates.count) coordinates")

        // Remove existing route if any
        do {
            if mapView.mapboxMap.layerExists(withId: "route-layer") {
                try mapView.mapboxMap.removeLayer(withId: "route-layer")
            }
            if mapView.mapboxMap.sourceExists(withId: "route-source") {
                try mapView.mapboxMap.removeSource(withId: "route-source")
            }
        } catch {
            print("⚠️ Could not remove existing route: \(error.localizedDescription)")
        }

        var feature = Feature(geometry: .lineString(LineString(coordinates)))
        feature.identifier = .string("route")

        var source = GeoJSONSource(id: "route-source")
        source.data = .feature(feature)

        do {
            try mapView.mapboxMap.addSource(source)

            var routeLayer = LineLayer(id: "route-layer", source: "route-source")
            routeLayer.lineColor = .constant(StyleColor(.systemBlue)) // Blue for truck routes
            routeLayer.lineWidth = .constant(6)
            routeLayer.lineCap = .constant(.round)
            routeLayer.lineJoin = .constant(.round)

            try mapView.mapboxMap.addLayer(routeLayer)

            print("✅ Truck route line drawn on map (blue)")
        } catch {
            print("❌ Failed to draw route on map: \(error.localizedDescription)")
        }
    }
}

extension NavigationViewController: UISearchBarDelegate {
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

extension NavigationViewController: UITableViewDelegate, UITableViewDataSource {
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

extension NavigationViewController: CLLocationManagerDelegate {
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
