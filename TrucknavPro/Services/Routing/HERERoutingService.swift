//
//  HERERoutingService.swift
//  TruckNavPro
//
//  HERE Routing API v8 - Truck-specific routing with restrictions
//

import Foundation
import CoreLocation
import MapboxDirections

class HERERoutingService {

    private let apiKey: String
    private let routingURL = "https://router.hereapi.com/v8"

    struct TruckParameters {
        let weight: Double      // kg (convert from lbs)
        let height: Double      // meters (convert from ft)
        let width: Double       // meters (convert from ft)
        let length: Double      // meters (convert from ft)
        let axleCount: Int
        let trailerCount: Int
        let hazardousMaterials: [String]?

        // Convert from Imperial units (used in app)
        static func fromImperial(weightLbs: Double, heightFt: Double, widthFt: Double, lengthFt: Double = 53.0) -> TruckParameters {
            return TruckParameters(
                weight: weightLbs * 0.453592,        // lbs to kg
                height: heightFt * 0.3048,           // ft to meters
                width: widthFt * 0.3048,             // ft to meters
                length: lengthFt * 0.3048,           // ft to meters
                axleCount: 5,
                trailerCount: 1,
                hazardousMaterials: nil
            )
        }
    }

    struct HERERoute {
        let id: String
        let sections: [RouteSection]
        let totalDistance: Double      // meters
        let totalDuration: Double      // seconds
        let tollCosts: TollCosts?
        let polyline: String           // Encoded polyline

        struct RouteSection {
            let distance: Double       // meters
            let duration: Double       // seconds
            let instructions: [Instruction]
            let speedLimits: [SpeedLimit]?

            struct Instruction {
                let text: String
                let distance: Double
                let coordinate: CLLocationCoordinate2D
                let action: String     // "turn", "depart", "arrive", etc.
                let direction: String? // "left", "right", "straight"
            }

            struct SpeedLimit {
                let maxSpeed: Double   // km/h
                let roadType: String
            }
        }

        struct TollCosts {
            let currency: String
            let total: Double
            let details: [TollDetail]

            struct TollDetail {
                let name: String
                let cost: Double
                let country: String?
            }
        }
    }

    init(apiKey: String) {
        self.apiKey = apiKey
        print("🚛 HERE Routing Service initialized with API key: \(apiKey.prefix(10))...")
    }

    // MARK: - Calculate Truck Route

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        truckParams: TruckParameters,
        avoidTolls: Bool = false,
        completion: @escaping (Result<HERERoute, Error>) -> Void
    ) {
        var urlComponents = URLComponents(string: "\(routingURL)/routes")!

        // Build query parameters
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "transportMode", value: "truck"),
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "return", value: "polyline,summary,actions,instructions,turnByTurnActions,elevation,tolls")
        ]

        // Truck-specific parameters
        queryItems.append(URLQueryItem(name: "truck[grossWeight]", value: String(format: "%.0f", truckParams.weight)))
        queryItems.append(URLQueryItem(name: "truck[height]", value: String(format: "%.2f", truckParams.height)))
        queryItems.append(URLQueryItem(name: "truck[width]", value: String(format: "%.2f", truckParams.width)))
        queryItems.append(URLQueryItem(name: "truck[length]", value: String(format: "%.2f", truckParams.length)))
        queryItems.append(URLQueryItem(name: "truck[axleCount]", value: "\(truckParams.axleCount)"))
        queryItems.append(URLQueryItem(name: "truck[trailerCount]", value: "\(truckParams.trailerCount)"))

        // Hazmat restrictions
        if let hazmat = truckParams.hazardousMaterials, !hazmat.isEmpty {
            for material in hazmat {
                queryItems.append(URLQueryItem(name: "truck[shippedHazardousGoods]", value: material))
            }
        }

        // Avoid options
        if avoidTolls {
            queryItems.append(URLQueryItem(name: "avoid[features]", value: "tollRoad"))
        }

        // Route preferences
        queryItems.append(URLQueryItem(name: "alternatives", value: "3")) // Get 3 alternative routes
        queryItems.append(URLQueryItem(name: "units", value: "imperial"))  // Match app units

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "HERERouting", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🚛 HERE Truck Routing from \(origin) to \(destination)")
        print("   Weight: \(String(format: "%.0f", truckParams.weight))kg, Height: \(String(format: "%.2f", truckParams.height))m")
        print("🌐 URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Routing error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HERE Routing response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorMsg = "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    completion(.failure(NSError(domain: "HERERouting", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
            }

            guard let data = data else {
                print("❌ HERE Routing: No data received")
                completion(.failure(NSError(domain: "HERERouting", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response preview
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 HERE Routing response preview: \(jsonString.prefix(500))...")
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(HERERoutingResponse.self, from: data)

                guard let firstRoute = response.routes.first else {
                    completion(.failure(NSError(domain: "HERERouting", code: -3, userInfo: [NSLocalizedDescriptionKey: "No routes found"])))
                    return
                }

                // Parse route sections
                let sections = firstRoute.sections.map { section -> HERERoute.RouteSection in
                    let instructions = section.actions?.map { action -> HERERoute.RouteSection.Instruction in
                        return HERERoute.RouteSection.Instruction(
                            text: action.instruction ?? "",
                            distance: action.length ?? 0,
                            coordinate: CLLocationCoordinate2D(
                                latitude: action.offset ?? 0,
                                longitude: 0
                            ),
                            action: action.action ?? "",
                            direction: action.direction
                        )
                    } ?? []

                    return HERERoute.RouteSection(
                        distance: section.summary.length,
                        duration: section.summary.duration,
                        instructions: instructions,
                        speedLimits: nil
                    )
                }

                // Parse toll costs
                var tollCosts: HERERoute.TollCosts?
                if let tolls = firstRoute.sections.first?.tolls {
                    let details = tolls.map { toll -> HERERoute.TollCosts.TollDetail in
                        HERERoute.TollCosts.TollDetail(
                            name: toll.name ?? "Toll",
                            cost: toll.fares?.first?.price ?? 0,
                            country: toll.country
                        )
                    }

                    let total = details.reduce(0) { $0 + $1.cost }
                    tollCosts = HERERoute.TollCosts(
                        currency: tolls.first?.fares?.first?.currencyCode ?? "USD",
                        total: total,
                        details: details
                    )
                }

                let route = HERERoute(
                    id: firstRoute.id,
                    sections: sections,
                    totalDistance: sections.reduce(0) { $0 + $1.distance },
                    totalDuration: sections.reduce(0) { $0 + $1.duration },
                    tollCosts: tollCosts,
                    polyline: firstRoute.sections.first?.polyline ?? ""
                )

                print("✅ HERE Route calculated: \(String(format: "%.1f", route.totalDistance / 1609.34)) mi, \(String(format: "%.0f", route.totalDuration / 60)) min")
                if let tolls = route.tollCosts {
                    print("💰 Toll costs: \(tolls.currency) \(String(format: "%.2f", tolls.total))")
                }

                completion(.success(route))
            } catch {
                print("❌ HERE Routing decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Get Speed Limits

    func getSpeedLimits(
        at coordinates: [CLLocationCoordinate2D],
        completion: @escaping (Result<[SpeedLimitResult], Error>) -> Void
    ) {
        // HERE Speed Limits API - requires route polyline or coordinates
        let coordsString = coordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
        let urlString = "\(routingURL)/speedlimits?apiKey=\(apiKey)&coordinates=\(coordsString)"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "HERERouting", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🚦 HERE Speed Limits API: \(coordinates.count) coordinates")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Speed Limits error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("❌ HERE Speed Limits: No data received")
                completion(.failure(NSError(domain: "HERERouting", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Parse speed limits response
            // Note: This is a placeholder - actual implementation would depend on API response format
            completion(.success([]))
        }.resume()
    }

    struct SpeedLimitResult {
        let coordinate: CLLocationCoordinate2D
        let speedLimit: Double  // km/h
        let roadType: String
    }
}

// MARK: - Response Models

struct HERERoutingResponse: Codable {
    let routes: [Route]

    struct Route: Codable {
        let id: String
        let sections: [Section]

        struct Section: Codable {
            let id: String
            let type: String
            let summary: Summary
            let polyline: String?
            let actions: [Action]?
            let tolls: [Toll]?

            struct Summary: Codable {
                let duration: Double    // seconds
                let length: Double      // meters
                let baseDuration: Double?
            }

            struct Action: Codable {
                let action: String?
                let duration: Double?
                let length: Double?
                let instruction: String?
                let offset: Double?
                let direction: String?
                let severity: String?
            }

            struct Toll: Codable {
                let name: String?
                let country: String?
                let fares: [Fare]?

                struct Fare: Codable {
                    let price: Double?
                    let currencyCode: String?
                }
            }
        }
    }
}
