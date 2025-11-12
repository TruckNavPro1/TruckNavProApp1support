//
//  HERETrafficService.swift
//  TruckNavPro
//
//  HERE Real-Time Traffic API v7 - Fallback for TomTom
//

import Foundation
import CoreLocation

class HERETrafficService {

    private let apiKey: String
    private let trafficURL = "https://data.traffic.hereapi.com/v7"

    struct TrafficFlow {
        let currentSpeed: Double      // km/h
        let freeFlowSpeed: Double     // km/h
        let jamFactor: Double         // 0.0 - 10.0 (0 = no traffic, 10 = complete standstill)
        let confidence: Double        // 0.0 - 1.0
        let roadType: String

        var congestionLevel: CongestionLevel {
            if jamFactor >= 8.0 {
                return .severe
            } else if jamFactor >= 5.0 {
                return .heavy
            } else if jamFactor >= 2.0 {
                return .moderate
            } else {
                return .free
            }
        }

        var speedRatio: Double {
            guard freeFlowSpeed > 0 else { return 1.0 }
            return currentSpeed / freeFlowSpeed
        }
    }

    enum CongestionLevel: String {
        case free = "Free Flow"
        case moderate = "Moderate"
        case heavy = "Heavy"
        case severe = "Severe"
    }

    struct TrafficIncident {
        let id: String
        let type: String
        let description: String
        let coordinate: CLLocationCoordinate2D
        let startTime: Date?
        let endTime: Date?
        let severity: Int  // 0-10
        let delay: Int?    // seconds
        let length: Int?   // meters
    }

    init(apiKey: String) {
        self.apiKey = apiKey
        print("🚦 HERE Traffic Service initialized with API key: \(apiKey.prefix(10))...")
    }

    // MARK: - Traffic Flow

    func getTrafficFlow(at coordinate: CLLocationCoordinate2D, completion: @escaping (Result<TrafficFlow, Error>) -> Void) {
        // HERE Traffic API v7 - Flow endpoint
        let urlString = "\(trafficURL)/flow?apiKey=\(apiKey)&locationReferencing=shape&in=circle:\(coordinate.latitude),\(coordinate.longitude);r=500"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "HERETraffic", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🚦 HERE Traffic Flow API URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Traffic fetch error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HERE Traffic Flow response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorMsg = "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    completion(.failure(NSError(domain: "HERETraffic", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
            }

            guard let data = data else {
                print("❌ HERE Traffic: No data received")
                completion(.failure(NSError(domain: "HERETraffic", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response preview
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 HERE Traffic response preview: \(jsonString.prefix(500))")
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(HERETrafficFlowResponse.self, from: data)

                // Get first result (closest to location)
                guard let result = response.results.first else {
                    completion(.failure(NSError(domain: "HERETraffic", code: -3, userInfo: [NSLocalizedDescriptionKey: "No traffic data available"])))
                    return
                }

                let flow = TrafficFlow(
                    currentSpeed: result.currentFlow.speed ?? 0,
                    freeFlowSpeed: result.currentFlow.freeFlow ?? result.currentFlow.speed ?? 0,
                    jamFactor: result.currentFlow.jamFactor ?? 0,
                    confidence: result.currentFlow.confidence ?? 1.0,
                    roadType: result.location.description ?? "Road"
                )

                print("✅ HERE Traffic Flow: \(flow.currentSpeed) km/h (jam factor: \(flow.jamFactor))")
                completion(.success(flow))
            } catch {
                print("❌ HERE Traffic decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Traffic Incidents

    func getTrafficIncidents(in boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double), completion: @escaping (Result<[TrafficIncident], Error>) -> Void) {
        // HERE Traffic API v7 - Incidents endpoint
        let bbox = "\(boundingBox.minLon),\(boundingBox.minLat),\(boundingBox.maxLon),\(boundingBox.maxLat)"
        let urlString = "\(trafficURL)/incidents?apiKey=\(apiKey)&in=bbox:\(bbox)&locationReferencing=shape"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "HERETraffic", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🚨 HERE Traffic Incidents API URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Incidents error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HERE Traffic Incidents response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorMsg = "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    completion(.failure(NSError(domain: "HERETraffic", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
            }

            guard let data = data else {
                print("❌ HERE Incidents: No data received")
                completion(.failure(NSError(domain: "HERETraffic", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response preview
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 HERE Incidents response preview: \(jsonString.prefix(500))")
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(HERETrafficIncidentsResponse.self, from: data)

                let incidents = response.results.map { result -> TrafficIncident in
                    // Get first coordinate from location shape
                    let coord: CLLocationCoordinate2D
                    if let shape = result.location.shape, !shape.links.isEmpty, !shape.links[0].points.isEmpty {
                        let point = shape.links[0].points[0]
                        coord = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng)
                    } else {
                        coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
                    }

                    // Map criticality string to severity number
                    let severity: Int
                    switch result.incidentDetails.criticality?.lowercased() {
                    case "critical": severity = 3
                    case "major": severity = 2
                    case "minor": severity = 1
                    default: severity = 0
                    }

                    return TrafficIncident(
                        id: result.incidentDetails.id,
                        type: result.incidentDetails.type,
                        description: result.incidentDetails.description.value,
                        coordinate: coord,
                        startTime: nil,  // HERE v7 uses different time format
                        endTime: nil,
                        severity: severity,
                        delay: nil,
                        length: result.incidentDetails.length
                    )
                }

                print("✅ HERE Traffic Incidents found: \(incidents.count)")
                completion(.success(incidents))
            } catch {
                print("❌ HERE Incidents decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Response Models

struct HERETrafficFlowResponse: Codable {
    struct Result: Codable {
        let location: Location
        let currentFlow: Flow

        struct Location: Codable {
            let description: String?
            let shape: Shape?

            struct Shape: Codable {
                let links: [Link]

                struct Link: Codable {
                    let points: [Point]

                    struct Point: Codable {
                        let lat: Double
                        let lng: Double
                    }
                }
            }
        }

        struct Flow: Codable {
            let speed: Double?
            let freeFlow: Double?
            let jamFactor: Double?
            let confidence: Double?
        }
    }

    let results: [Result]
}

struct HERETrafficIncidentsResponse: Codable {
    struct Result: Codable {
        let incidentDetails: IncidentDetails
        let location: Location

        struct IncidentDetails: Codable {
            let id: String
            let type: String
            let typeDescription: Description?
            let description: Description
            let summary: Description?
            let criticality: String?
            let length: Int?

            struct Description: Codable {
                let value: String
                let language: String?
            }
        }

        struct Location: Codable {
            let shape: Shape?

            struct Shape: Codable {
                let links: [Link]

                struct Link: Codable {
                    let points: [Point]

                    struct Point: Codable {
                        let lat: Double
                        let lng: Double
                    }
                }
            }
        }
    }

    let results: [Result]
}
