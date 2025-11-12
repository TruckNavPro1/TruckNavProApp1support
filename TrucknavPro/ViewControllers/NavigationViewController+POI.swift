//
//  NavigationViewController+POI.swift
//  TruckNavPro
//
//  POI (Points of Interest) integration for MapViewController

import UIKit
import MapboxMaps
import CoreLocation

extension MapViewController {

    // MARK: - POI Setup

    func setupPOIManager() {
        // Create separate annotation manager for POIs
        poiAnnotationManager = navigationMapView.mapView.annotations.makePointAnnotationManager()

        // Fetch initial POIs if location is available
        if let location = locationManager.location {
            fetchAndDisplayPOIs(near: location)
        }

        print("✅ POI manager initialized")
    }

    // MARK: - Fetch POIs

    func fetchAndDisplayPOIs(near location: CLLocation, radius: Double = 50_000) {
        Task {
            do {
                // Fetch POIs from Supabase
                let pois = try await POIService.shared.fetchPOIsNear(
                    location: location,
                    radius: radius,
                    types: enabledPOITypes()  // Based on user settings
                )

                await MainActor.run {
                    displayPOIs(pois)
                }

                print("✅ Displayed \(pois.count) POIs on map")
            } catch {
                print("❌ Failed to fetch POIs: \(error.localizedDescription)")
            }
        }
    }

    /// Fetch POIs along the active route
    func fetchPOIsAlongRoute(routeCoordinates: [CLLocationCoordinate2D]) {
        Task {
            do {
                let pois = try await POIService.shared.fetchPOIsAlongRoute(
                    routeCoordinates: routeCoordinates,
                    bufferMeters: 5000,  // 5km buffer on each side
                    types: enabledPOITypes()
                )

                await MainActor.run {
                    displayPOIs(pois)
                }

                print("✅ Displayed \(pois.count) POIs along route")
            } catch {
                print("❌ Failed to fetch route POIs: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Display POIs

    private func displayPOIs(_ pois: [POI]) {
        guard let poiManager = poiAnnotationManager else { return }

        // Clear existing POI annotations
        poiManager.annotations = []

        // Create annotations for each POI
        var annotations: [PointAnnotation] = []

        for poi in pois {
            var annotation = PointAnnotation(coordinate: poi.coordinate)
            annotation.image = .init(image: getIconImage(for: poi.type), name: poi.type.rawValue)
            annotation.iconSize = 0.8

            // Store POI ID in userInfo for tap handling
            annotation.userInfo = ["poi_id": poi.id]

            annotations.append(annotation)
        }

        // Add all annotations at once
        poiManager.annotations = annotations

        // Store POIs for reference
        currentPOIs = pois

        print("📍 Displayed \(annotations.count) POI markers on map")
    }

    // MARK: - POI Icons

    private func getIconImage(for type: POIType) -> UIImage {
        // Create colored icon based on POI type
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        let symbolImage = UIImage(systemName: type.iconName, withConfiguration: config)
        let color = UIColor(hexString: type.markerColor) ?? .systemBlue

        // Render icon with color
        return symbolImage?.withTintColor(color, renderingMode: .alwaysOriginal) ?? UIImage()
    }

    // MARK: - POI Type Filtering

    private func enabledPOITypes() -> [POIType]? {
        // Get user preferences from settings (implement later)
        // For now, return all types
        return [.truckStop, .restArea, .weighStation, .parking, .fuelStation]
    }

    // MARK: - POI Tap Handling

    func handlePOITap(poiId: String) {
        // Find the POI
        guard let poi = currentPOIs.first(where: { $0.id == poiId }) else {
            print("⚠️ POI not found: \(poiId)")
            return
        }

        // Show POI detail view
        showPOIDetail(for: poi)
    }

    private func showPOIDetail(for poi: POI) {
        let detailVC = POIDetailViewController(poi: poi)
        detailVC.modalPresentationStyle = .pageSheet

        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        present(detailVC, animated: true)
        print("📍 Showing details for: \(poi.name)")
    }

    // MARK: - Map Movement Handling

    func updatePOIsForMapRegion() {
        // Update POIs when map moves significantly
        guard let location = locationManager.location else { return }

        // Check if we've moved far enough to warrant a refresh
        if let lastLocation = lastPOIFetchLocation,
           location.distance(from: lastLocation) < 10_000 {  // 10km threshold
            return
        }

        lastPOIFetchLocation = location
        fetchAndDisplayPOIs(near: location)
    }
}

// MARK: - POI Storage

extension MapViewController {
    private static var poiAnnotationManagerKey: UInt8 = 0
    private static var currentPOIsKey: UInt8 = 0
    private static var lastPOIFetchLocationKey: UInt8 = 0

    var poiAnnotationManager: PointAnnotationManager? {
        get {
            objc_getAssociatedObject(self, &Self.poiAnnotationManagerKey) as? PointAnnotationManager
        }
        set {
            objc_setAssociatedObject(self, &Self.poiAnnotationManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var currentPOIs: [POI] {
        get {
            (objc_getAssociatedObject(self, &Self.currentPOIsKey) as? [POI]) ?? []
        }
        set {
            objc_setAssociatedObject(self, &Self.currentPOIsKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var lastPOIFetchLocation: CLLocation? {
        get {
            objc_getAssociatedObject(self, &Self.lastPOIFetchLocationKey) as? CLLocation
        }
        set {
            objc_setAssociatedObject(self, &Self.lastPOIFetchLocationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
