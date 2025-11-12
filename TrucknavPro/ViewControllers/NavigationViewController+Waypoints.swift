//
//  NavigationViewController+Waypoints.swift
//  TrucknavPro
//
//  Multi-stop waypoint management and route optimization
//

import UIKit
import CoreLocation
import MapboxMaps

extension MapViewController {

    // MARK: - Waypoint Management

    struct Stop {
        let id: String
        let name: String
        let address: String?
        let coordinate: CLLocationCoordinate2D
        var isCompleted: Bool = false
        var estimatedArrival: Date?  // ETA for this stop

        init(id: String = UUID().uuidString, name: String, address: String? = nil, coordinate: CLLocationCoordinate2D, isCompleted: Bool = false, estimatedArrival: Date? = nil) {
            self.id = id
            self.name = name
            self.address = address
            self.coordinate = coordinate
            self.isCompleted = isCompleted
            self.estimatedArrival = estimatedArrival
        }
    }

    // MARK: - Setup Waypoint UI

    func setupWaypointUI() {
        // Setup stops panel content
        setupStopsPanelContent()

        // Add to view hierarchy
        view.addSubview(addStopButton)
        view.addSubview(stopsPanel)

        // Store trailing constraint for collapse animation
        stopsPanelTrailingConstraint = stopsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor)

        NSLayoutConstraint.activate([
            // Add Stop button (stacked below settings button)
            addStopButton.topAnchor.constraint(equalTo: settingsButton.bottomAnchor, constant: 16),
            addStopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addStopButton.widthAnchor.constraint(equalToConstant: 44),
            addStopButton.heightAnchor.constraint(equalToConstant: 44),

            // Stops panel (slides in from right, aligned with add stop button)
            stopsPanel.topAnchor.constraint(equalTo: addStopButton.bottomAnchor, constant: 10),
            stopsPanelTrailingConstraint!,
            stopsPanel.widthAnchor.constraint(equalToConstant: 300),
            stopsPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])

        // Initially hide stops panel
        stopsPanel.transform = CGAffineTransform(translationX: 300, y: 0)
        stopsPanel.isHidden = true
    }

    private func setupStopsPanelContent() {
        // Add header
        let header = createStopsPanelHeader()
        stopsPanel.addSubview(header)

        // Add table view
        stopsPanel.addSubview(stopsTableView)

        // Add optimize button
        stopsPanel.addSubview(optimizeButton)

        // Layout
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: stopsPanel.topAnchor),
            header.leadingAnchor.constraint(equalTo: stopsPanel.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: stopsPanel.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 60),

            stopsTableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            stopsTableView.leadingAnchor.constraint(equalTo: stopsPanel.leadingAnchor),
            stopsTableView.trailingAnchor.constraint(equalTo: stopsPanel.trailingAnchor),
            stopsTableView.bottomAnchor.constraint(equalTo: optimizeButton.topAnchor, constant: -8),

            optimizeButton.leadingAnchor.constraint(equalTo: stopsPanel.leadingAnchor, constant: 16),
            optimizeButton.trailingAnchor.constraint(equalTo: stopsPanel.trailingAnchor, constant: -16),
            optimizeButton.bottomAnchor.constraint(equalTo: stopsPanel.bottomAnchor, constant: -16),
            optimizeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func createStopsPanelHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = .secondarySystemBackground

        let titleLabel = UILabel()
        titleLabel.text = "Route Stops"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let collapseButton = UIButton(type: .system)
        collapseButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        collapseButton.tintColor = .secondaryLabel
        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        collapseButton.tag = 999  // Tag for easy reference
        collapseButton.addTarget(self, action: #selector(toggleCollapsedState), for: .touchUpInside)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeStopsPanel), for: .touchUpInside)

        header.addSubview(titleLabel)
        header.addSubview(collapseButton)
        header.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),

            collapseButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            collapseButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            collapseButton.widthAnchor.constraint(equalToConstant: 30),
            collapseButton.heightAnchor.constraint(equalToConstant: 30),

            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        return header
    }

    // MARK: - Actions

    @objc func addStopTapped() {
        // Show search interface to add stop
        showAddStopSearch()
        toggleStopsPanel(show: true)
    }

    @objc func closeStopsPanel() {
        toggleStopsPanel(show: false)
    }

    @objc func toggleCollapsedState() {
        isStopsPanelCollapsed.toggle()
        animateCollapsedState()
    }

    internal func animateCollapsedState() {
        // Update chevron icon
        if let collapseButton = stopsPanel.subviews.first?.viewWithTag(999) as? UIButton {
            let chevronImage = UIImage(systemName: isStopsPanelCollapsed ? "chevron.left" : "chevron.right")
            collapseButton.setImage(chevronImage, for: .normal)
        }

        // Animate constraint change
        if isStopsPanelCollapsed {
            stopsPanelTrailingConstraint?.constant = -250  // Show only 50px edge
        } else {
            stopsPanelTrailingConstraint?.constant = 0     // Show full 300px width
        }

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }

        print(isStopsPanelCollapsed ? "📍 Stops panel collapsed" : "📍 Stops panel expanded")
    }

    private func toggleStopsPanel(show: Bool) {
        if show {
            // Show panel - clear collapsed state and reset transform
            isStopsPanelCollapsed = false
            stopsPanelTrailingConstraint?.constant = 0
            stopsPanel.transform = .identity
            stopsPanel.isHidden = false
            view.layoutIfNeeded()
        } else {
            // Hide panel - slide off screen
            UIView.animate(withDuration: 0.3) {
                self.stopsPanel.transform = CGAffineTransform(translationX: 300, y: 0)
            } completion: { _ in
                self.stopsPanel.isHidden = true
            }
        }
    }

    @objc func optimizeRouteTapped() {
        guard stops.count >= 2 else {
            showAlert(title: "Need More Stops", message: "Add at least 2 stops to optimize the route.")
            return
        }

        // Show loading
        optimizeButton.isEnabled = false
        optimizeButton.setTitle("⏳ Optimizing...", for: .normal)

        // Get current location as start
        guard let currentLocation = locationManager.location?.coordinate else {
            optimizeButton.isEnabled = true
            optimizeButton.setTitle("🎯 Optimize Route", for: .normal)
            showAlert(title: "Location Error", message: "Cannot determine current location")
            return
        }

        let start = HEREWaypointService.Waypoint(coordinate: currentLocation, name: "Current Location")
        let waypoints = stops.map { HEREWaypointService.Waypoint(coordinate: $0.coordinate, name: $0.name) }

        // Call HERE Waypoints Sequence API
        waypointService?.optimizeWaypoints(start: start, stops: waypoints, end: nil, truckProfile: currentTruckProfile) { [weak self] result in
            DispatchQueue.main.async {
                self?.optimizeButton.isEnabled = true
                self?.optimizeButton.setTitle("🎯 Optimize Route", for: .normal)

                switch result {
                case .success(let optimizedRoute):
                    // Update stops order
                    self?.handleOptimizedRoute(optimizedRoute)

                case .failure(let error):
                    print("❌ Route optimization failed: \(error.localizedDescription)")
                    self?.showAlert(title: "Optimization Failed", message: "Could not optimize route: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleOptimizedRoute(_ route: HEREWaypointService.OptimizedRoute) {
        // Update stops array with optimized order (skip first waypoint as it's current location)
        let optimizedStops = route.waypoints.dropFirst().enumerated().compactMap { (index, waypoint) -> Stop? in
            // Find matching stop
            return stops.first { $0.coordinate.latitude == waypoint.lat && $0.coordinate.longitude == waypoint.lng }
        }

        stops = optimizedStops
        stopsTableView.reloadData()

        // Update map markers
        updateStopMarkers()

        // Calculate and display optimized route
        calculateMultiStopRoute()

        // Show success message
        let distance = Double(route.distance) / 1609.34 // meters to miles
        let duration = Double(route.duration) / 60 // seconds to minutes
        showAlert(title: "Route Optimized! ✅", message: String(format: "\(stops.count) stops\n%.1f miles\n%.0f minutes", distance, duration))
    }

    // MARK: - Stop Management

    func addStop(_ stop: Stop) {
        stops.append(stop)
        stopsTableView.reloadData()
        updateStopMarkers()

        // Calculate route through all stops
        calculateMultiStopRoute()
    }

    func removeStop(at index: Int) {
        guard index < stops.count else { return }
        stops.remove(at: index)
        stopsTableView.reloadData()
        updateStopMarkers()

        if !stops.isEmpty {
            calculateMultiStopRoute()
        } else {
            clearRoute()
        }
    }

    func markStopCompleted(at index: Int) {
        guard index < stops.count else { return }
        stops[index].isCompleted = true
        stopsTableView.reloadData()
        updateStopMarkers()

        // Navigate to next stop if available
        if index + 1 < stops.count {
            navigateToStop(at: index + 1)
        } else {
            // All stops completed!
            showAlert(title: "Route Complete! 🎉", message: "You've completed all stops on your route.")
            clearRoute()
        }
    }

    // MARK: - Map Markers

    func updateStopMarkers() {
        // Clear existing markers
        stopAnnotationManager?.annotations = []

        var annotations: [PointAnnotation] = []

        for (index, stop) in stops.enumerated() {
            var annotation = PointAnnotation(coordinate: stop.coordinate)

            // Create numbered marker icon
            let iconImage = createNumberedMarker(number: index + 1, isCompleted: stop.isCompleted)
            annotation.image = .init(image: iconImage, name: "stop-\(index)")
            annotation.iconAnchor = .bottom

            // Don't show text labels - they cluster and look messy
            // Stop names are visible in the stops panel instead

            annotations.append(annotation)
        }

        stopAnnotationManager?.annotations = annotations
        print("🗺️ Updated \(annotations.count) stop markers on map")
    }

    private func createNumberedMarker(number: Int, isCompleted: Bool) -> UIImage {
        let size = CGSize(width: 40, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Draw pin shape
            let pinColor = isCompleted ? UIColor.systemGreen : UIColor.systemBlue
            pinColor.setFill()

            // Pin body (circle)
            let circlePath = UIBezierPath(ovalIn: CGRect(x: 5, y: 5, width: 30, height: 30))
            circlePath.fill()

            // Pin point (triangle)
            let trianglePath = UIBezierPath()
            trianglePath.move(to: CGPoint(x: 20, y: 35))
            trianglePath.addLine(to: CGPoint(x: 15, y: 45))
            trianglePath.addLine(to: CGPoint(x: 25, y: 45))
            trianglePath.close()
            trianglePath.fill()

            // Draw number
            let numberString = "\(number)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let textSize = numberString.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: 12,
                width: textSize.width,
                height: textSize.height
            )

            numberString.draw(in: textRect, withAttributes: attributes)
        }
    }

    // MARK: - Route Calculation

    private func calculateMultiStopRoute() {
        guard !stops.isEmpty else { return }
        guard let currentLocation = locationManager.location?.coordinate else { return }

        print("🗺️ Calculating multi-stop route with \(stops.count) stops")

        // Calculate route through all waypoints using HERE Routing
        guard let hereRouting = hereRoutingService else {
            print("⚠️ HERE Routing service not available")
            return
        }

        // Last stop is the destination
        let destination = stops.last!.coordinate

        // All stops except the last are intermediate waypoints
        let intermediateWaypoints = stops.count > 1 ? Array(stops.dropLast().map { $0.coordinate }) : []

        // Use truck profile from settings
        let truckParams = HERERoutingService.TruckParameters.fromImperial(
            weightLbs: Double(truckWeightLbs),
            heightFt: truckHeightFeet,
            widthFt: truckWidthFeet
        )

        print("🚛 Calculating truck route: \(currentLocation) → \(destination) with \(intermediateWaypoints.count) intermediate stops")

        // Calculate route with Mapbox for navigation mode
        // (HERE routing was for optimization only)
        let allStopCoordinates = stops.map { $0.coordinate }

        print("🗺️ Triggering Mapbox navigation with \(allStopCoordinates.count) stops")
        calculateMapboxMultiStopRoute(from: currentLocation, through: allStopCoordinates)
    }

    private func navigateToStop(at index: Int) {
        guard index < stops.count else { return }
        let stop = stops[index]

        print("🧭 Navigating to stop \(index + 1): \(stop.name)")
        // TODO: Start turn-by-turn navigation to this stop
    }

    private func clearRoute() {
        stops.removeAll()
        stopsTableView.reloadData()
        stopAnnotationManager?.annotations = []
    }

    // MARK: - Add Stop Search

    private func showAddStopSearch() {
        let alert = UIAlertController(title: "Add Stop", message: "Enter address or location name", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "e.g., 123 Main St, Nashville, TN"
            textField.autocapitalizationType = .words
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let searchText = alert?.textFields?.first?.text, !searchText.isEmpty else { return }

            // Geocode the address
            self?.geocodeAddress(searchText) { result in
                switch result {
                case .success(let coordinate):
                    let stop = Stop(name: searchText, coordinate: coordinate)
                    self?.addStop(stop)

                case .failure(let error):
                    self?.showAlert(title: "Location Not Found", message: "Could not find '\(searchText)': \(error.localizedDescription)")
                }
            }
        })

        present(alert, animated: true)
    }

    private func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        let geocoder = CLGeocoder()

        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let location = placemarks?.first?.location?.coordinate else {
                completion(.failure(NSError(domain: "Geocoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "No location found"])))
                return
            }

            completion(.success(location))
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Table View Data Source & Delegate

extension MapViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard tableView == stopsTableView else { return 0 }
        return stops.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard tableView == stopsTableView else { return UITableViewCell() }

        let cell = tableView.dequeueReusableCell(withIdentifier: "StopCell", for: indexPath) as! StopCell
        let stop = stops[indexPath.row]
        cell.configure(stop: stop, number: indexPath.row + 1)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let stop = stops[indexPath.row]

        let alert = UIAlertController(title: stop.name, message: "What would you like to do?", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Navigate Here", style: .default) { [weak self] _ in
            self?.navigateToStop(at: indexPath.row)
        })

        alert.addAction(UIAlertAction(title: "Mark Completed", style: .default) { [weak self] _ in
            self?.markStopCompleted(at: indexPath.row)
        })

        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.removeStop(at: indexPath.row)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad support
        if let popover = alert.popoverPresentationController {
            if let cell = tableView.cellForRow(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }

        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            removeStop(at: indexPath.row)
        }
    }
}

// MARK: - Drag & Drop Delegates

extension MapViewController: UITableViewDragDelegate, UITableViewDropDelegate {

    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let stop = stops[indexPath.row]
        let itemProvider = NSItemProvider(object: stop.id as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }

        coordinator.items.forEach { item in
            guard let sourceIndexPath = item.sourceIndexPath else { return }

            tableView.performBatchUpdates({
                let stop = stops.remove(at: sourceIndexPath.row)
                stops.insert(stop, at: destinationIndexPath.row)
                tableView.deleteRows(at: [sourceIndexPath], with: .automatic)
                tableView.insertRows(at: [destinationIndexPath], with: .automatic)
            })

            coordinator.drop(item.dragItem, toRowAt: destinationIndexPath)
            updateStopMarkers()
            calculateMultiStopRoute()  // Recalculate route with new order
        }
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
}

// MARK: - Stop Cell

class StopCell: UITableViewCell {

    private let numberLabel = UILabel()
    private let nameLabel = UILabel()
    private let etaLabel = UILabel()
    private let checkmarkImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        numberLabel.font = .systemFont(ofSize: 20, weight: .bold)
        numberLabel.textColor = .systemBlue
        numberLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        etaLabel.font = .systemFont(ofSize: 13, weight: .regular)
        etaLabel.textColor = .secondaryLabel
        etaLabel.translatesAutoresizingMaskIntoConstraints = false

        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.tintColor = .systemGreen
        checkmarkImageView.isHidden = true
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(numberLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(etaLabel)
        contentView.addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            numberLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            numberLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 30),

            nameLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -8),

            etaLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 12),
            etaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            etaLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -8),

            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func configure(stop: MapViewController.Stop, number: Int) {
        numberLabel.text = "\(number)"
        nameLabel.text = stop.name
        checkmarkImageView.isHidden = !stop.isCompleted

        // Format ETA
        if let eta = stop.estimatedArrival {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            etaLabel.text = "Arrive: \(formatter.string(from: eta))"
            etaLabel.isHidden = false
        } else {
            etaLabel.isHidden = true
        }

        if stop.isCompleted {
            numberLabel.textColor = .systemGreen
            nameLabel.textColor = .secondaryLabel
            etaLabel.textColor = .tertiaryLabel
        } else {
            numberLabel.textColor = .systemBlue
            nameLabel.textColor = .label
            etaLabel.textColor = .secondaryLabel
        }
    }
}
