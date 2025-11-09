//
//  TruckSettings.swift
//  TruckNavPro
//
//  User settings storage with UserDefaults persistence
//

import Foundation

struct TruckSettings {

    // MARK: - UserDefaults Keys

    private static let heightKey = "truck_height"
    private static let widthKey = "truck_width"
    private static let weightKey = "truck_weight"
    private static let hazmatKey = "truck_hazmat"
    private static let avoidTollsKey = "avoid_tolls"
    private static let avoidHighwaysKey = "avoid_highways"
    private static let avoidFerriesKey = "avoid_ferries"
    private static let unitsKey = "units_imperial"
    private static let mapStyleKey = "map_style"
    private static let voiceVolumeKey = "voice_volume"

    // MARK: - Truck Specifications

    /// Truck height in meters (default: 4.11m = 13'6")
    static var height: Double {
        get {
            let saved = UserDefaults.standard.double(forKey: heightKey)
            return saved != 0 ? saved : 4.11
        }
        set {
            UserDefaults.standard.set(newValue, forKey: heightKey)
        }
    }

    /// Truck width in meters (default: 2.44m = 8')
    static var width: Double {
        get {
            let saved = UserDefaults.standard.double(forKey: widthKey)
            return saved != 0 ? saved : 2.44
        }
        set {
            UserDefaults.standard.set(newValue, forKey: widthKey)
        }
    }

    /// Truck weight in metric tons (default: 36.287t = 80,000 lbs)
    static var weight: Double {
        get {
            let saved = UserDefaults.standard.double(forKey: weightKey)
            return saved != 0 ? saved : 36.287
        }
        set {
            UserDefaults.standard.set(newValue, forKey: weightKey)
        }
    }

    /// Hazmat cargo indicator
    static var hazmat: Bool {
        get {
            UserDefaults.standard.bool(forKey: hazmatKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hazmatKey)
        }
    }

    // MARK: - Navigation Preferences

    /// Avoid toll roads
    static var avoidTolls: Bool {
        get {
            UserDefaults.standard.bool(forKey: avoidTollsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: avoidTollsKey)
        }
    }

    /// Avoid highways/motorways
    static var avoidHighways: Bool {
        get {
            UserDefaults.standard.bool(forKey: avoidHighwaysKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: avoidHighwaysKey)
        }
    }

    /// Avoid ferries
    static var avoidFerries: Bool {
        get {
            UserDefaults.standard.bool(forKey: avoidFerriesKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: avoidFerriesKey)
        }
    }

    // MARK: - Display Settings

    /// Use imperial units (miles, feet) instead of metric (default: false = metric)
    static var useImperialUnits: Bool {
        get {
            UserDefaults.standard.object(forKey: unitsKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: unitsKey)
        }
    }

    /// Map style preference
    enum MapStyle: String {
        case auto = "Auto"
        case day = "Day"
        case night = "Night"
    }

    static var mapStyle: MapStyle {
        get {
            let rawValue = UserDefaults.standard.string(forKey: mapStyleKey) ?? "Auto"
            return MapStyle(rawValue: rawValue) ?? .auto
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: mapStyleKey)
        }
    }

    /// Voice guidance volume (0-100)
    static var voiceVolume: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: voiceVolumeKey)
            return saved != 0 ? saved : 100
        }
        set {
            UserDefaults.standard.set(min(100, max(0, newValue)), forKey: voiceVolumeKey)
        }
    }

    // MARK: - Helper Methods

    /// Reset all settings to defaults
    static func resetToDefaults() {
        height = 4.11
        width = 2.44
        weight = 36.287
        hazmat = false
        avoidTolls = false
        avoidHighways = false
        avoidFerries = false
        useImperialUnits = true
        mapStyle = .auto
        voiceVolume = 100
    }

    /// Format height for display
    static func formattedHeight() -> String {
        if useImperialUnits {
            let feet = Int(height * 3.28084)
            let inches = Int((height * 39.3701).truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\" (\(String(format: "%.2f", height))m)"
        } else {
            return "\(String(format: "%.2f", height))m"
        }
    }

    /// Format width for display
    static func formattedWidth() -> String {
        if useImperialUnits {
            let feet = height * 3.28084
            return "\(String(format: "%.1f", feet))' (\(String(format: "%.2f", width))m)"
        } else {
            return "\(String(format: "%.2f", width))m"
        }
    }

    /// Format weight for display
    static func formattedWeight() -> String {
        if useImperialUnits {
            let lbs = weight * 2204.62
            return "\(String(format: "%.0f", lbs)) lbs (\(String(format: "%.1f", weight))t)"
        } else {
            return "\(String(format: "%.1f", weight))t"
        }
    }
}
