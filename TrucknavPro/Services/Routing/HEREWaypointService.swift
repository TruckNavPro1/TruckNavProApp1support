//
//  HEREWaypointService.swift
//  TrucknavPro
//
//  Multi-stop route optimization using HERE Waypoints Sequence v8 API
//

import Foundation
import CoreLocation

class HEREWaypointService {

    // MARK: - Models

    struct Waypoint: Codable {
        let id: String
        let lat: Double
        let lng: Double
        let name: String?

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        init(id: String = UUID().uuidString, coordinate: CLLocationCoordinate2D, name: String? = nil) {
            self.id = id
            self.lat = coordinate.latitude
            self.lng = coordinate.longitude
            self.name = name
        }
    }

    struct TruckProfile {
        let height: Double?      // meters
        let weight: Double?      // kilograms
        let width: Double?       // meters
        let axleCount: Int?
        let trailerCount: Int?
        let isHazmat: Bool

        static var `default`: TruckProfile {
            TruckProfile(
                height: 4.11,        // 13'6" in meters
                weight: 36287,       // 80,000 lbs in kg
                width: 2.59,         // 8'6" in meters
                axleCount: 5,
                trailerCount: 1,
                isHazmat: false
            )
        }

        var queryParameters: [String: String] {
            var params: [String: String] = [:]

            if let height = height {
                params["vehicle[height]"] = "\(height)"
            }
            if let weight = weight {
                params["vehicle[weight]"] = "\(weight)"
            }
            if let width = width {
                params["vehicle[width]"] = "\(width)"
            }
            if let axleCount = axleCount {
                params["vehicle[axleCount]"] = "\(axleCount)"
            }
            if let trailerCount = trailerCount {
                params["vehicle[trailerCount]"] = "\(trailerCount)"
            }
            if isHazmat {
                params["vehicle[shippedHazardousGoods]"] = "explosive,gas,flammable,combustible,organic,poison,radioActive,corrosive,poisonousInhalation,harmfulToWater,other"
            }

            return params
        }
    }

    struct OptimizedRoute {
        let waypoints: [Waypoint]    // In optimized order
        let distance: Int            // meters
        let duration: Int            // seconds
        let savings: RouteSavings?

        struct RouteSavings {
            let distanceSaved: Int   // meters
            let timeSaved: Int       // seconds
        }
    }

    // MARK: - Properties

    private let apiKey: String
    private let baseURL = "https://wps.hereapi.com/v8/findsequence2"

    // MARK: - Init

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - API Methods

    /// Optimize the order of waypoints for most efficient route
    func optimizeWaypoints(
        start: Waypoint,
        stops: [Waypoint],
        end: Waypoint? = nil,
        truckProfile: TruckProfile = .default,
        completion: @escaping (Result<OptimizedRoute, Error>) -> Void
    ) {
        guard !stops.isEmpty else {
            completion(.failure(NSError(domain: "HEREWaypointService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No stops provided"])))
            return
        }

        // Build request URL with query parameters (v8 uses GET, not POST)
        var components = URLComponents(string: baseURL)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "mode", value: "fastest;truck;traffic:enabled"),
            URLQueryItem(name: "improveFor", value: "time")
        ]

        // Add departure time (required by API)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let departureTime = dateFormatter.string(from: Date())
        queryItems.append(URLQueryItem(name: "departure", value: departureTime))

        // Add start location (format: lat,lng)
        queryItems.append(URLQueryItem(name: "start", value: "\(start.lat),\(start.lng)"))

        // Add all stops as destinations
        for (index, stop) in stops.enumerated() {
            queryItems.append(URLQueryItem(name: "destination\(index + 1)", value: "\(stop.lat),\(stop.lng)"))
        }

        // Add end location if specified
        if let end = end {
            queryItems.append(URLQueryItem(name: "end", value: "\(end.lat),\(end.lng)"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            completion(.failure(NSError(domain: "HEREWaypointService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🗺️ HERE Waypoints Sequence Request (GET): \(url.absoluteString)")

        // Make GET request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Waypoints error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "HEREWaypointService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🗺️ HERE Waypoints Response: \(jsonString.prefix(500))...")
            }

            do {
                let response = try JSONDecoder().decode(WaypointSequenceResponse.self, from: data)

                guard let results = response.results?.first else {
                    completion(.failure(NSError(domain: "HEREWaypointService", code: -4, userInfo: [NSLocalizedDescriptionKey: "No results in response"])))
                    return
                }

                // Parse optimized waypoint order from v8 API response
                guard let waypointsResult = results.waypoints else {
                    completion(.failure(NSError(domain: "HEREWaypointService", code: -5, userInfo: [NSLocalizedDescriptionKey: "No waypoints in response"])))
                    return
                }

                // Sort waypoints by sequence number
                let sortedWaypoints = waypointsResult.sorted { $0.sequence < $1.sequence }

                // Map back to original waypoints using ID
                var optimizedWaypoints: [Waypoint] = []
                for waypointResult in sortedWaypoints {
                    if waypointResult.id == "start" {
                        optimizedWaypoints.append(start)
                    } else if waypointResult.id == "end" {
                        if let end = end {
                            optimizedWaypoints.append(end)
                        }
                    } else if waypointResult.id.hasPrefix("destination") {
                        // Extract index from "destination1", "destination2", etc.
                        if let indexStr = waypointResult.id.components(separatedBy: "destination").last,
                           let index = Int(indexStr), index > 0, index <= stops.count {
                            optimizedWaypoints.append(stops[index - 1])
                        }
                    }
                }

                // Calculate savings if available
                var savings: OptimizedRoute.RouteSavings?
                if results.distance != nil, results.time != nil {
                    // Compare to non-optimized route (would need separate calculation)
                    // For now, show absolute values
                    savings = OptimizedRoute.RouteSavings(distanceSaved: 0, timeSaved: 0)
                }

                let optimizedRoute = OptimizedRoute(
                    waypoints: optimizedWaypoints,
                    distance: results.distanceMeters,
                    duration: results.durationSeconds,
                    savings: savings
                )

                print("✅ HERE Waypoints optimized: \(optimizedWaypoints.count) stops, \(results.distanceMeters)m, \(results.durationSeconds)s")

                completion(.success(optimizedRoute))

            } catch {
                print("❌ HERE Waypoints decode error: \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }

    // MARK: - Response Models

    private struct WaypointSequenceResponse: Codable {
        let results: [SequenceResult]?
        let errors: [String]?
    }

    private struct SequenceResult: Codable {
        let waypoints: [WaypointResult]?  // Waypoints in optimized sequence
        let distance: String?             // Total distance in meters (returned as string by API)
        let time: String?                 // Total time in seconds (returned as string by API)
        let description: String?

        var distanceMeters: Int {
            return Int(distance ?? "0") ?? 0
        }

        var durationSeconds: Int {
            return Int(time ?? "0") ?? 0
        }
    }

    private struct WaypointResult: Codable {
        let id: String
        let lat: Double
        let lng: Double
        let sequence: Int                 // Optimized sequence number
        let estimatedArrival: String?
        let estimatedDeparture: String?
    }
}
