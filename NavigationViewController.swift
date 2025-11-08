//
//  NavigationViewController.swift
//  TruckNavPro
//

import UIKit
import MapboxMaps
import CoreLocation
import Combine

class NavigationViewController: UIViewController {
    
    private var mapView: MapView!
    private let locationManager = CLLocationManager()
    private var cancelables = Set<AnyCancelable>()
    private var lastBearing: CLLocationDirection = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupMapView()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func setupMapView() {
        let mapInitOptions = MapInitOptions(styleURI: .streets)
        mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        
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
