//
//  POI.swift
//  TruckNavPro
//
//  Point of Interest models for truck stops, rest areas, weigh stations

import Foundation
import CoreLocation

// MARK: - POI Type

enum POIType: String, Codable {
    case truckStop = "truck_stop"
    case restArea = "rest_area"
    case weighStation = "weigh_station"
    case parking = "truck_parking"
    case fuelStation = "fuel_station"
    case service = "service_center"

    var displayName: String {
        switch self {
        case .truckStop: return "Truck Stop"
        case .restArea: return "Rest Area"
        case .weighStation: return "Weigh Station"
        case .parking: return "Truck Parking"
        case .fuelStation: return "Fuel Station"
        case .service: return "Service Center"
        }
    }

    var iconName: String {
        switch self {
        case .truckStop: return "building.2.fill"
        case .restArea: return "bed.double.fill"
        case .weighStation: return "scalemass.fill"
        case .parking: return "parkingsign.circle.fill"
        case .fuelStation: return "fuelpump.fill"
        case .service: return "wrench.and.screwdriver.fill"
        }
    }

    var markerColor: String {
        switch self {
        case .truckStop: return "#FF6B35"      // Orange
        case .restArea: return "#4ECDC4"        // Teal
        case .weighStation: return "#FFD93D"    // Yellow
        case .parking: return "#6C5CE7"         // Purple
        case .fuelStation: return "#00B894"     // Green
        case .service: return "#FF7675"         // Red
        }
    }
}

// MARK: - POI Model

struct POI: Codable, Identifiable {
    let id: String
    let type: POIType
    let name: String
    let address: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let latitude: Double
    let longitude: Double
    let phone: String?
    let website: String?
    let amenities: [String]
    let brands: [String]?
    let rating: Double?
    let reviewCount: Int?
    let isOpen24Hours: Bool
    let operatingHours: [String: String]?  // Day of week -> hours
    let createdAt: Date?
    let updatedAt: Date?

    // Computed properties
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var fullAddress: String {
        var components: [String] = []
        if let address = address { components.append(address) }
        if let city = city { components.append(city) }
        if let state = state { components.append(state) }
        if let zip = zipCode { components.append(zip) }
        return components.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id, type, name, address, city, state
        case zipCode = "zip_code"
        case latitude, longitude, phone, website, amenities, brands
        case rating
        case reviewCount = "review_count"
        case isOpen24Hours = "is_open_24_hours"
        case operatingHours = "operating_hours"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - POI Amenities

struct POIAmenity {
    static let showers = "showers"
    static let restrooms = "restrooms"
    static let wifi = "wifi"
    static let restaurant = "restaurant"
    static let fastFood = "fast_food"
    static let laundry = "laundry"
    static let atm = "atm"
    static let parking = "parking"
    static let scales = "scales"
    static let diesel = "diesel"
    static let def = "def"
    static let repairs = "repairs"
    static let tireService = "tire_service"
    static let store = "store"
    static let truckerLounge = "trucker_lounge"
    static let gaming = "gaming"
    static let mailService = "mail_service"
    static let faxCopy = "fax_copy"
    static let dogPark = "dog_park"
    static let secureParking = "secure_parking"

    static func displayName(for amenity: String) -> String {
        switch amenity {
        case showers: return "Showers"
        case restrooms: return "Restrooms"
        case wifi: return "WiFi"
        case restaurant: return "Restaurant"
        case fastFood: return "Fast Food"
        case laundry: return "Laundry"
        case atm: return "ATM"
        case parking: return "Parking"
        case scales: return "CAT Scales"
        case diesel: return "Diesel Fuel"
        case def: return "DEF"
        case repairs: return "Repairs"
        case tireService: return "Tire Service"
        case store: return "Convenience Store"
        case truckerLounge: return "Trucker Lounge"
        case gaming: return "Gaming"
        case mailService: return "Mail Service"
        case faxCopy: return "Fax/Copy"
        case dogPark: return "Dog Park"
        case secureParking: return "Secure Parking"
        default: return amenity.capitalized
        }
    }

    static func iconName(for amenity: String) -> String {
        switch amenity {
        case showers: return "shower.fill"
        case restrooms: return "toilet.fill"
        case wifi: return "wifi"
        case restaurant: return "fork.knife"
        case fastFood: return "bag.fill"
        case laundry: return "washer.fill"
        case atm: return "banknote.fill"
        case parking: return "parkingsign.circle.fill"
        case scales: return "scalemass.fill"
        case diesel: return "fuelpump.fill"
        case def: return "drop.fill"
        case repairs: return "wrench.fill"
        case tireService: return "circle.fill"
        case store: return "cart.fill"
        case truckerLounge: return "sofa.fill"
        case gaming: return "gamecontroller.fill"
        case mailService: return "envelope.fill"
        case faxCopy: return "printer.fill"
        case dogPark: return "pawprint.fill"
        case secureParking: return "lock.shield.fill"
        default: return "checkmark.circle.fill"
        }
    }
}

// MARK: - POI Review

struct POIReview: Codable, Identifiable {
    let id: String
    let poiId: String
    let userId: String?
    let userName: String?
    let rating: Double
    let comment: String?
    let amenityRatings: [String: Double]?  // Amenity -> rating
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case poiId = "poi_id"
        case userId = "user_id"
        case userName = "user_name"
        case rating, comment
        case amenityRatings = "amenity_ratings"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - POI Search Filter

struct POISearchFilter {
    var types: [POIType] = []
    var amenities: [String] = []
    var minRating: Double?
    var maxDistance: Double?  // In meters
    var isOpen24Hours: Bool?
    var brands: [String] = []

    var isEmpty: Bool {
        types.isEmpty &&
        amenities.isEmpty &&
        minRating == nil &&
        maxDistance == nil &&
        isOpen24Hours == nil &&
        brands.isEmpty
    }
}
