//
//  TomTomSearchService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation
import MapboxSearchUI

class TomTomSearchService {

    private let apiKey: String
    private let baseURL = "https://api.tomtom.com/search/2"

    // Truck-specific POI categories
    enum TruckCategory: Int, CaseIterable {
        case truckStop = 7315
        case restArea = 7365
        case weighStation = 7395
        case truckParking = 7318
        case fuelStation = 7311
        case mechanic = 7303
        case hotel = 7313
        case restaurant = 7315000

        var displayName: String {
            switch self {
            case .truckStop: return "Truck Stops"
            case .restArea: return "Rest Areas"
            case .weighStation: return "Weigh Stations"
            case .truckParking: return "Truck Parking"
            case .fuelStation: return "Fuel Stations"
            case .mechanic: return "Repair Shops"
            case .hotel: return "Hotels"
            case .restaurant: return "Restaurants"
            }
        }

        var icon: String {
            switch self {
            case .truckStop: return "fuelpump.circle.fill"
            case .restArea: return "bed.double.fill"
            case .weighStation: return "scalemass.fill"
            case .truckParking: return "parkingsign.circle.fill"
            case .fuelStation: return "fuelpump.fill"
            case .mechanic: return "wrench.and.screwdriver.fill"
            case .hotel: return "building.2.fill"
            case .restaurant: return "fork.knife.circle.fill"
            }
        }
    }

    struct TruckSearchResult {
        let id: String
        let name: String
        let category: String
        let distance: Double  // meters
        let coordinate: CLLocationCoordinate2D
        let address: String
        let phone: String?
        let categories: [String]
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Search by Category

    func searchCategory(
        _ category: TruckCategory,
        near coordinate: CLLocationCoordinate2D,
        radius: Int = 100000,  // 100km default
        limit: Int = 20,
        completion: @escaping (Result<[TruckSearchResult], Error>) -> Void
    ) {
        let urlString = "\(baseURL)/categorySearch/\(category.rawValue).json?key=\(apiKey)&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&radius=\(radius)&limit=\(limit)"

        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            completion(.failure(NSError(domain: "TomTomSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🔍 TomTom Search: \(category.displayName) near \(coordinate)")

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TomTomSearch", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SearchResponse.self, from: data)

                let results = response.results.map { result -> TruckSearchResult in
                    TruckSearchResult(
                        id: result.id,
                        name: result.poi?.name ?? result.address?.freeformAddress ?? "Unknown",
                        category: result.poi?.categories?.first ?? "Unknown",
                        distance: result.dist ?? 0,
                        coordinate: CLLocationCoordinate2D(
                            latitude: result.position.lat,
                            longitude: result.position.lon
                        ),
                        address: result.address?.freeformAddress ?? "Unknown",
                        phone: result.poi?.phone,
                        categories: result.poi?.categories ?? []
                    )
                }

                print("✅ Found \(results.count) \(category.displayName)")
                completion(.success(results))
            } catch {
                print("❌ TomTom Search decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Free Text Search

    func searchText(
        _ query: String,
        near coordinate: CLLocationCoordinate2D,
        limit: Int = 10,
        completion: @escaping (Result<[TruckSearchResult], Error>) -> Void
    ) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/\(encodedQuery).json?key=\(apiKey)&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&limit=\(limit)&typeahead=true"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TomTomSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TomTomSearch", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SearchResponse.self, from: data)

                let results = response.results.map { result -> TruckSearchResult in
                    TruckSearchResult(
                        id: result.id,
                        name: result.poi?.name ?? result.address?.freeformAddress ?? "Unknown",
                        category: result.poi?.categories?.first ?? "Unknown",
                        distance: result.dist ?? 0,
                        coordinate: CLLocationCoordinate2D(
                            latitude: result.position.lat,
                            longitude: result.position.lon
                        ),
                        address: result.address?.freeformAddress ?? "Unknown",
                        phone: result.poi?.phone,
                        categories: result.poi?.categories ?? []
                    )
                }

                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Response Models

struct SearchResponse: Codable {
    struct Result: Codable {
        let id: String
        let type: String
        let score: Double
        let dist: Double?
        let poi: POI?
        let address: Address?
        let position: Position

        struct POI: Codable {
            let name: String
            let phone: String?
            let categories: [String]?
        }

        struct Address: Codable {
            let freeformAddress: String
            let municipality: String?
            let countrySubdivision: String?
            let postalCode: String?
            let country: String?
        }

        struct Position: Codable {
            let lat: Double
            let lon: Double
        }
    }

    struct Summary: Codable {
        let queryType: String
        let queryTime: Int
        let numResults: Int
        let totalResults: Int
    }

    let summary: Summary
    let results: [Result]
}
