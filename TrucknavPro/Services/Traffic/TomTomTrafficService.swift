//
//  TomTomTrafficService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation
import MapboxMaps

class TomTomTrafficService {

    private let apiKey: String
    private let baseFlowURL = "https://api.tomtom.com/traffic/services/4/flowSegmentData"
    private let baseIncidentURL = "https://api.tomtom.com/traffic/services/5/incidentDetails"

    // Fast URLSession with short timeout for better performance
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12.0  // 8 second timeout
        config.timeoutIntervalForResource = 20.0  // 15 second total timeout
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Traffic Flow

    struct TrafficFlow {
        let freeFlowSpeed: Int
        let currentSpeed: Int
        let congestion: Int  // 0=flow, 1=slow, 2=congestion, 3=heavy
        let confidence: Double
        let roadClosure: Bool
    }

    func getTrafficFlow(
        at coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<TrafficFlow, Error>) -> Void
    ) {
        // Correct TomTom Traffic Flow API format: /absolute/{zoom}/json
        let zoom = 10  // Zoom level for detail (10-22)
        let urlString = "\(baseFlowURL)/absolute/\(zoom)/json?key=\(apiKey)&point=\(coordinate.latitude),\(coordinate.longitude)"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TomTomTraffic", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🚦 Traffic Flow API URL: \(url.absoluteString)")

        urlSession.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Traffic Flow network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Traffic Flow response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorMsg = "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    completion(.failure(NSError(domain: "TomTomTraffic", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TomTomTraffic", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response preview
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Traffic Flow response preview: \(jsonString.prefix(300))")
            }

            do {
                struct Response: Codable {
                    struct FlowData: Codable {
                        let freeFlowSpeed: Int?
                        let currentSpeed: Int?
                        let confidence: Double?
                        let roadClosure: Bool?

                        // Congestion is calculated, not directly provided
                        var congestion: Int {
                            guard let free = freeFlowSpeed, let current = currentSpeed else { return 0 }
                            let ratio = Double(current) / Double(free)
                            if ratio >= 0.75 { return 0 } // Free flow
                            if ratio >= 0.5 { return 1 }  // Slow
                            if ratio >= 0.25 { return 2 } // Congestion
                            return 3 // Heavy congestion
                        }
                    }
                    let flowSegmentData: FlowData
                }

                let response = try JSONDecoder().decode(Response.self, from: data)
                let flow = TrafficFlow(
                    freeFlowSpeed: response.flowSegmentData.freeFlowSpeed ?? 50,
                    currentSpeed: response.flowSegmentData.currentSpeed ?? 50,
                    congestion: response.flowSegmentData.congestion,
                    confidence: response.flowSegmentData.confidence ?? 0.5,
                    roadClosure: response.flowSegmentData.roadClosure ?? false
                )
                completion(.success(flow))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Traffic Incidents

    struct TrafficIncident {
        let id: String
        let type: Int  // 1=accident, 2=roadwork, 3=closure, etc.
        let severity: String  // Severe, High, Medium, Minor
        let coordinate: CLLocationCoordinate2D
        let description: String
    }

    func getTrafficIncidents(
        in boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double),
        completion: @escaping (Result<[TrafficIncident], Error>) -> Void
    ) {
        // TomTom Traffic Incidents API format: /incidentDetails/s3/{bbox}/10/json
        // bbox format: minLon,minLat,maxLon,maxLat (note: lon,lat order!)
        let bbox = "\(boundingBox.minLon),\(boundingBox.minLat),\(boundingBox.maxLon),\(boundingBox.maxLat)"
        let urlString = "\(baseIncidentURL)/s3/\(bbox)/10/json?key=\(apiKey)&timeValidityFilter=present&categoryFilter=1,2,3,8"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TomTomTraffic", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🚨 Traffic Incidents API URL: \(url.absoluteString)")

        urlSession.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Traffic Incidents network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Traffic Incidents response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorMsg = "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    print("❌ \(errorMsg)")
                    completion(.failure(NSError(domain: "TomTomTraffic", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TomTomTraffic", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response preview
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Traffic Incidents response preview: \(jsonString.prefix(300))")
            }

            do {
                struct Response: Codable {
                    struct Incident: Codable {
                        struct Properties: Codable {
                            let id: String
                            let iconCategory: Int
                            let magnitudeOfDelay: Int?
                            let events: [Event]?

                            struct Event: Codable {
                                let description: String?
                                let code: Int
                            }
                        }
                        struct Geometry: Codable {
                            let coordinates: [[Double]]?
                            let type: String
                        }

                        let properties: Properties
                        let geometry: Geometry
                    }
                    let features: [Incident]?
                }

                let decoder = JSONDecoder()
                let response = try decoder.decode(Response.self, from: data)

                let incidents = (response.features ?? []).compactMap { incident -> TrafficIncident? in
                    guard let coords = incident.geometry.coordinates?.first else { return nil }

                    // Extract severity based on magnitude of delay
                    let severity: String
                    if let magnitude = incident.properties.magnitudeOfDelay {
                        switch magnitude {
                        case 0: severity = "Minor"
                        case 1: severity = "Medium"
                        case 2: severity = "High"
                        case 3...Int.max: severity = "Severe"
                        default: severity = "Unknown"
                        }
                    } else {
                        severity = "Medium"
                    }

                    let description = incident.properties.events?.first?.description ?? "Traffic incident"

                    return TrafficIncident(
                        id: incident.properties.id,
                        type: incident.properties.iconCategory,
                        severity: severity,
                        coordinate: CLLocationCoordinate2D(
                            latitude: coords[1],  // TomTom uses [lon, lat] format
                            longitude: coords[0]
                        ),
                        description: description
                    )
                }

                completion(.success(incidents))
            } catch {
                print("❌ TomTom Traffic decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}
