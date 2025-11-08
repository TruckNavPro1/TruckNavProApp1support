//
//  ContentView.swift
//  TruckNavPro
//

import SwiftUI
import MapboxMaps
import CoreLocation
import Combine

struct ContentView: View {
    @StateObject private var locationDebug = LocationDebugger()
    
    var body: some View {
        ZStack {
            MapViewRepresentable(locationDebug: locationDebug)
                .ignoresSafeArea()
            
            // Debug overlay
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🗺️ Map: \(locationDebug.mapLoaded ? "Loaded" : "Loading...")")
                        Text("📍 Puck: \(locationDebug.puckConfigured ? "Set" : "Not Set")")
                        Text("🔐 Auth: \(locationDebug.authStatus)")
                        Text("📡 Location: \(locationDebug.locationText)")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
    }
}

class LocationDebugger: ObservableObject {
    @Published var mapLoaded = false
    @Published var puckConfigured = false
    @Published var authStatus = "Unknown"
    @Published var locationText = "No location"
}

struct MapViewRepresentable: UIViewRepresentable {
    @ObservedObject var locationDebug: LocationDebugger
    
    func makeUIView(context: Context) -> MapView {
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let cameraOptions = CameraOptions(center: center, zoom: 14)
        let mapInitOptions = MapInitOptions(cameraOptions: cameraOptions)
        
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)
        
        mapView.mapboxMap.onStyleLoaded.observeNext { _ in
            DispatchQueue.main.async {
                self.locationDebug.mapLoaded = true
            }
            print("✅ Style loaded")
            
            var puckConfig = Puck2DConfiguration()
            puckConfig.showsAccuracyRing = true
            puckConfig.pulsing = .default
            
            mapView.location.options.puckType = .puck2D(puckConfig)
            mapView.location.options.puckBearingEnabled = true
            
            DispatchQueue.main.async {
                self.locationDebug.puckConfigured = true
            }
            print("✅ Puck configured")
            
            mapView.location.onLocationChange.observe { [weak mapView] locations in
                if let location = locations.last {
                    let lat = String(format: "%.4f", location.coordinate.latitude)
                    let lon = String(format: "%.4f", location.coordinate.longitude)
                    DispatchQueue.main.async {
                        self.locationDebug.locationText = "\(lat), \(lon)"
                    }
                    print("📍 Location: \(lat), \(lon)")
                    
                    // Auto-center on user location using Coordinator flag
                    if !context.coordinator.hasMovedToUserLocation {
                        context.coordinator.hasMovedToUserLocation = true
                        print("🎯 Auto-centering on user location...")
                        
                        mapView?.camera.ease(
                            to: CameraOptions(
                                center: location.coordinate,
                                zoom: 15
                            ),
                            duration: 1.5
                        )
                    }
                }
            }.store(in: &context.coordinator.cancelBag)
            
        }.store(in: &context.coordinator.cancelBag)
        
        context.coordinator.requestLocationPermission(locationDebug: locationDebug)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MapView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var cancelBag = Set<AnyCancelable>()
        let locationManager = CLLocationManager()
        var hasMovedToUserLocation = false  // Track if we've centered yet
        
        override init() {
            super.init()
            locationManager.delegate = self
        }
        
        func requestLocationPermission(locationDebug: LocationDebugger) {
            print("🔐 Requesting location...")
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let status = self.locationManager.authorizationStatus
                locationDebug.authStatus = self.authStatusString(status)
                print("📱 Auth: \(locationDebug.authStatus)")
            }
        }
        
        func authStatusString(_ status: CLAuthorizationStatus) -> String {
            switch status {
            case .authorizedAlways: return "Always"
            case .authorizedWhenInUse: return "When In Use"
            case .denied: return "Denied"
            case .restricted: return "Restricted"
            case .notDetermined: return "Not Asked"
            @unknown default: return "Unknown"
            }
        }
    }
}

extension MapViewRepresentable.Coordinator: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("🔐 Auth changed: \(manager.authorizationStatus.rawValue)")
    }
}

#Preview {
    ContentView()
}
