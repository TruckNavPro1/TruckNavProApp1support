//
//  NavigationViewController+Traffic.swift
//  TruckNavPro
//
//  Traffic widget integration for MapViewController
//

import UIKit
import CoreLocation
import Foundation

extension MapViewController {

    // MARK: - Traffic Widget Storage

    private static var trafficWidgetKey: UInt8 = 0

    var trafficWidget: TrafficWidgetView {
        get {
            if let widget = objc_getAssociatedObject(self, &Self.trafficWidgetKey) as? TrafficWidgetView {
                return widget
            }
            let widget = TrafficWidgetView()
            widget.translatesAutoresizingMaskIntoConstraints = false
            objc_setAssociatedObject(self, &Self.trafficWidgetKey, widget, .OBJC_ASSOCIATION_RETAIN)
            return widget
        }
    }

    // MARK: - Setup

    func setupTrafficWidget() {
        print("🚦 Setting up traffic widget...")
        view.addSubview(trafficWidget)

        // Find weather widget to position traffic widget below it
        guard let weatherWidget = view.subviews.first(where: { $0 is WeatherWidgetView }) else {
            print("⚠️ Weather widget not found, using fallback positioning")
            // Fallback: position at top if weather widget not found
            NSLayoutConstraint.activate([
                trafficWidget.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 120),
                trafficWidget.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                trafficWidget.widthAnchor.constraint(lessThanOrEqualToConstant: 180)
            ])
            return
        }

        print("✅ Positioning traffic widget below weather widget")
        // Position below weather widget
        NSLayoutConstraint.activate([
            trafficWidget.topAnchor.constraint(equalTo: weatherWidget.bottomAnchor, constant: 12),
            trafficWidget.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            trafficWidget.widthAnchor.constraint(lessThanOrEqualToConstant: 180)
        ])

        // Start auto-update if location is available
        if let location = locationManager.location {
            if hereTrafficService != nil || tomTomTrafficService != nil {
                print("🚦 Starting traffic auto-updates for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                trafficWidget.startAutoUpdate(
                    location: location.coordinate,
                    hereService: hereTrafficService,
                    tomTomService: tomTomTrafficService
                )
                print("✅ Traffic widget initialized with auto-updates")
                if hereTrafficService != nil {
                    print("   - Using HERE Traffic as primary")
                }
            } else {
                print("⚠️ No traffic services available")
                print("   Traffic widget will show error state")
            }
        } else {
            print("⚠️ Traffic widget setup incomplete:")
            print("   - Location not available yet")
            print("   Traffic widget will show loading state until location is available")
        }
    }

    // MARK: - Update Traffic Widget

    func updateTrafficWidgetLocation() {
        // Update traffic widget when location changes significantly
        guard let location = locationManager.location else { return }
        guard hereTrafficService != nil || tomTomTrafficService != nil else { return }

        // Restart auto-update with new location
        trafficWidget.startAutoUpdate(
            location: location.coordinate,
            hereService: hereTrafficService,
            tomTomService: tomTomTrafficService
        )
    }

    func stopTrafficWidget() {
        trafficWidget.stopAutoUpdate()
        print("🚦 Traffic widget stopped")
    }
}
