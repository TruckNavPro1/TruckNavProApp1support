//
//  TomTomRoutingService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation

// MARK: - Truck Parameters

struct TruckParameters {
    // IMPERIAL UNITS (Primary storage - American standards)
    var weightLbs: Int?         // pounds (max 80,000 lbs)
    var axleWeightLbs: Int?     // pounds (tandem: 34,000 lbs, single: 20,000 lbs)
    var lengthFeet: Double?     // feet (typical: 53 ft for trailer)
    var widthFeet: Double?      // feet (standard: 8.5 ft, max: 8.6 ft)
    var heightFeet: Double?     // feet (standard: 13.5 ft / 13'6")

    var commercialVehicle: Bool = true
    var loadType: [String]? // e.g., ["USHazmatClass1", "USHazmatClass2"]

    // Route Avoidances
    var avoidTolls: Bool = false
    var avoidMotorways: Bool = false
    var avoidFerries: Bool = false
    var avoidUnpavedRoads: Bool = true
    var avoidTunnels: Bool = false // Enable for hazmat
    var avoidBorderCrossings: Bool = false

    // MARK: - Default US Semi-Truck Configuration
    static var standardSemiTruck: TruckParameters {
        return TruckParameters(
            weightLbs: 80000,           // Federal max: 80,000 lbs
            axleWeightLbs: 34000,       // Tandem axle max: 34,000 lbs
            lengthFeet: 70.0,           // Tractor (17') + Trailer (53') = 70 ft total
            widthFeet: 8.5,             // Standard width: 8.5 ft (102 inches)
            heightFeet: 13.5,           // Standard height: 13.5 ft (13'6")
            commercialVehicle: true,
            loadType: nil,
            avoidTolls: false,
            avoidMotorways: false,
            avoidFerries: false,
            avoidUnpavedRoads: true,
            avoidTunnels: false,
            avoidBorderCrossings: false
        )
    }

    // MARK: - Unit Conversions (for API calls - TomTom requires metric)

    private var weightKg: Int? {
        guard let lbs = weightLbs else { return nil }
        return Int(Double(lbs) * 0.453592) // 1 lb = 0.453592 kg
    }

    private var axleWeightKg: Int? {
        guard let lbs = axleWeightLbs else { return nil }
        return Int(Double(lbs) * 0.453592)
    }

    private var lengthMeters: Double? {
        guard let feet = lengthFeet else { return nil }
        return feet * 0.3048 // 1 ft = 0.3048 m
    }

    private var widthMeters: Double? {
        guard let feet = widthFeet else { return nil }
        return feet * 0.3048
    }

    private var heightMeters: Double? {
        guard let feet = heightFeet else { return nil }
        return feet * 0.3048
    }

    func toQueryParameters() -> [String: String] {
        var params: [String: String] = [:]

        // Convert Imperial to Metric for TomTom API
        if let weight = weightKg {
            params["vehicleWeight"] = "\(weight)"
        }
        if let axleWeight = axleWeightKg {
            params["vehicleAxleWeight"] = "\(axleWeight)"
        }
        if let length = lengthMeters {
            params["vehicleLength"] = String(format: "%.2f", length)
        }
        if let width = widthMeters {
            params["vehicleWidth"] = String(format: "%.2f", width)
        }
        if let height = heightMeters {
            params["vehicleHeight"] = String(format: "%.2f", height)
        }
        if commercialVehicle {
            params["vehicleCommercial"] = "true"
        }
        if let loadType = loadType {
            params["vehicleLoadType"] = loadType.joined(separator: ",")
        }

        // Build avoidance list
        var avoidances: [String] = []
        if avoidTolls { avoidances.append("tollRoads") }
        if avoidMotorways { avoidances.append("motorways") }
        if avoidFerries { avoidances.append("ferries") }
        if avoidUnpavedRoads { avoidances.append("unpavedRoads") }
        if avoidTunnels { avoidances.append("tunnels") }
        if avoidBorderCrossings { avoidances.append("borderCrossings") }

        if !avoidances.isEmpty {
            params["avoid"] = avoidances.joined(separator: ",")
        }

        return params
    }

    // MARK: - Display Helpers (for UI - user preference)

    func displayWeight(useMetric: Bool = false) -> String? {
        guard let lbs = weightLbs else { return nil }
        if useMetric {
            let kg = weightKg ?? 0
            return "\(kg) kg"
        } else {
            return "\(lbs) lbs"
        }
    }

    func displayHeight(useMetric: Bool = false) -> String? {
        guard let feet = heightFeet else { return nil }
        if useMetric {
            let meters = heightMeters ?? 0
            return String(format: "%.2f m", meters)
        } else {
            let inches = Int((feet.truncatingRemainder(dividingBy: 1)) * 12)
            let wholeFeet = Int(feet)
            return inches > 0 ? "\(wholeFeet)'\(inches)\"" : "\(wholeFeet)'"
        }
    }

    func displayWidth(useMetric: Bool = false) -> String? {
        guard let feet = widthFeet else { return nil }
        if useMetric {
            let meters = widthMeters ?? 0
            return String(format: "%.2f m", meters)
        } else {
            let inches = Int((feet.truncatingRemainder(dividingBy: 1)) * 12)
            let wholeFeet = Int(feet)
            return inches > 0 ? "\(wholeFeet)'\(inches)\"" : "\(wholeFeet)'"
        }
    }

    func displayLength(useMetric: Bool = false) -> String? {
        guard let feet = lengthFeet else { return nil }
        if useMetric {
            let meters = lengthMeters ?? 0
            return String(format: "%.1f m", meters)
        } else {
            return String(format: "%.1f ft", feet)
        }
    }
}

// MARK: - TomTom Response Models

struct TomTomRouteResponse: Codable {
    let routes: [TomTomRoute]
}

struct TomTomRoute: Codable {
    let summary: TomTomRouteSummary
    let legs: [TomTomLeg]
}

struct TomTomRouteSummary: Codable {
    let lengthInMeters: Int
    let travelTimeInSeconds: Int
    let trafficDelayInSeconds: Int?
    let departureTime: String?
    let arrivalTime: String?
}

struct TomTomLeg: Codable {
    let summary: TomTomRouteSummary
    let points: [TomTomPoint]
}

struct TomTomPoint: Codable {
    let latitude: Double
    let longitude: Double
}

struct TomTomGuidanceInstruction: Codable {
    let maneuver: String?
    let instruction: String
    let distance: Int
    let routeOffsetInMeters: Int?
}

// MARK: - Routing Service

class TomTomRoutingService {

    private let apiKey: String
    private let baseURL = "https://api.tomtom.com/routing/1/calculateRoute"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        truckParams: TruckParameters,
        completion: @escaping (Result<TomTomRouteResponse, Error>) -> Void
    ) {
        // Build coordinates string
        let coordinates = "\(origin.latitude),\(origin.longitude):\(destination.latitude),\(destination.longitude)"

        // Build URL
        var components = URLComponents(string: "\(baseURL)/\(coordinates)/json")

        // Base parameters
        var queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "travelMode", value: "truck"),
            URLQueryItem(name: "traffic", value: "true"),
            URLQueryItem(name: "routeType", value: "fastest"),
            URLQueryItem(name: "instructionsType", value: "text")
        ]

        // Add truck parameters
        let truckQueryParams = truckParams.toQueryParameters()
        for (key, value) in truckQueryParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(.failure(NSError(domain: "TomTomRouting", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🚛 TomTom API Request: \(url.absoluteString)")

        // Make request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TomTomRouting", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🚛 TomTom API Response: \(jsonString.prefix(500))...")
            }

            do {
                let decoder = JSONDecoder()
                let routeResponse = try decoder.decode(TomTomRouteResponse.self, from: data)
                completion(.success(routeResponse))
            } catch {
                print("❌ TomTom decode error: \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }
}

// MARK: - Route Conversion

extension TomTomRoute {
    func toCoordinates() -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []

        for leg in legs {
            for point in leg.points {
                coordinates.append(CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
            }
        }

        return coordinates
    }

    var distance: Double {
        return Double(summary.lengthInMeters)
    }

    var travelTime: TimeInterval {
        return TimeInterval(summary.travelTimeInSeconds)
    }
}
