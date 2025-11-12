//
//  POIImportService.swift
//  TruckNavPro
//
//  Service for importing real-world POI data from external APIs

import Foundation
import CoreLocation

class POIImportService {

    static let shared = POIImportService()

    private let supabaseService = SupabaseService.shared

    // OpenStreetMap Overpass API endpoint
    private let overpassAPIURL = "https://overpass-api.de/api/interpreter"

    // TomTom Places API (if you have API key)
    private let tomTomAPIKey: String? = nil // Set your TomTom API key here

    private init() {}

    // MARK: - Main Import Functions

    /// Import POIs for a specific region (state or bounding box)
    func importPOIsForRegion(
        minLat: Double,
        minLon: Double,
        maxLat: Double,
        maxLon: Double,
        progressHandler: @escaping (String, Int, Int) -> Void
    ) async throws {

        print("🌍 Starting POI import for region: (\(minLat),\(minLon)) to (\(maxLat),\(maxLon))")

        // Fetch from multiple sources
        let truckStops = try await fetchTruckStopsFromOSM(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        progressHandler("Fetched truck stops", 1, 5)

        let restAreas = try await fetchRestAreasFromOSM(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        progressHandler("Fetched rest areas", 2, 5)

        let weighStations = try await fetchWeighStationsFromOSM(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        progressHandler("Fetched weigh stations", 3, 5)

        let fuelStations = try await fetchFuelStationsFromOSM(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        progressHandler("Fetched fuel stations", 4, 5)

        // Combine all POIs
        let allPOIs = truckStops + restAreas + weighStations + fuelStations
        print("✅ Fetched \(allPOIs.count) total POIs from OpenStreetMap")

        // Upload to Supabase in batches
        try await uploadPOIsToSupabase(allPOIs, progressHandler: progressHandler)

        progressHandler("Import complete!", 5, 5)
    }

    /// Import POIs for common US trucking routes
    func importMajorTruckingRoutes(progressHandler: @escaping (String, Int, Int) -> Void) async throws {

        let majorRoutes: [(name: String, minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)] = [
            // I-40 (California to North Carolina)
            ("I-40 West", 34.0, -120.0, 36.0, -100.0),
            ("I-40 Central", 34.0, -100.0, 36.0, -80.0),
            ("I-40 East", 34.0, -80.0, 36.0, -75.0),

            // I-80 (California to New Jersey)
            ("I-80 West", 40.0, -125.0, 42.0, -110.0),
            ("I-80 Central", 40.0, -110.0, 42.0, -90.0),
            ("I-80 East", 40.0, -90.0, 42.0, -74.0),

            // I-10 (California to Florida)
            ("I-10 West", 30.0, -120.0, 34.0, -100.0),
            ("I-10 Central", 30.0, -100.0, 32.0, -85.0),
            ("I-10 East", 30.0, -85.0, 31.0, -81.0),

            // I-95 (Florida to Maine)
            ("I-95 South", 25.0, -82.0, 32.0, -79.0),
            ("I-95 Mid-Atlantic", 36.0, -78.0, 41.0, -73.0),
            ("I-95 Northeast", 41.0, -74.0, 45.0, -67.0)
        ]

        let total = majorRoutes.count
        for (index, route) in majorRoutes.enumerated() {
            print("🛣️ Importing POIs for \(route.name)...")
            progressHandler("Importing \(route.name)", index, total)

            try await importPOIsForRegion(
                minLat: route.minLat,
                minLon: route.minLon,
                maxLat: route.maxLat,
                maxLon: route.maxLon
            ) { _, _, _ in }

            // Delay to avoid rate limiting
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        progressHandler("All routes imported!", total, total)
    }

    // MARK: - OpenStreetMap Overpass API Queries

    private func fetchTruckStopsFromOSM(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [POIImportData] {

        // Overpass QL query for truck stops
        let query = """
        [out:json][timeout:60];
        (
          node["amenity"="fuel"]["hgv"="yes"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["amenity"="truck_stop"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          way["amenity"="fuel"]["hgv"="yes"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          way["amenity"="truck_stop"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out center tags;
        """

        let results = try await executeOverpassQuery(query)
        return results.map { osm in
            POIImportData(
                type: .truckStop,
                name: osm.tags["name"] ?? "Truck Stop",
                address: osm.tags["addr:street"],
                city: osm.tags["addr:city"],
                state: osm.tags["addr:state"],
                zipCode: osm.tags["addr:postcode"],
                latitude: osm.lat,
                longitude: osm.lon,
                phone: osm.tags["phone"],
                website: osm.tags["website"],
                amenities: extractAmenities(from: osm.tags),
                brands: extractBrands(from: osm.tags),
                isOpen24Hours: osm.tags["opening_hours"] == "24/7"
            )
        }
    }

    private func fetchRestAreasFromOSM(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [POIImportData] {

        let query = """
        [out:json][timeout:60];
        (
          node["highway"="rest_area"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["highway"="services"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          way["highway"="rest_area"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          way["highway"="services"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out center tags;
        """

        let results = try await executeOverpassQuery(query)
        return results.map { osm in
            POIImportData(
                type: .restArea,
                name: osm.tags["name"] ?? "Rest Area",
                address: osm.tags["addr:street"],
                city: osm.tags["addr:city"],
                state: osm.tags["addr:state"],
                zipCode: osm.tags["addr:postcode"],
                latitude: osm.lat,
                longitude: osm.lon,
                phone: osm.tags["phone"],
                website: osm.tags["website"],
                amenities: extractAmenities(from: osm.tags),
                brands: nil,
                isOpen24Hours: true
            )
        }
    }

    private func fetchWeighStationsFromOSM(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [POIImportData] {

        let query = """
        [out:json][timeout:60];
        (
          node["amenity"="weighbridge"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["highway"="weighbridge"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          way["amenity"="weighbridge"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out center tags;
        """

        let results = try await executeOverpassQuery(query)
        return results.map { osm in
            POIImportData(
                type: .weighStation,
                name: osm.tags["name"] ?? osm.tags["operator"] ?? "Weigh Station",
                address: osm.tags["addr:street"],
                city: osm.tags["addr:city"],
                state: osm.tags["addr:state"],
                zipCode: osm.tags["addr:postcode"],
                latitude: osm.lat,
                longitude: osm.lon,
                phone: osm.tags["phone"],
                website: osm.tags["website"],
                amenities: ["scales"],
                brands: nil,
                isOpen24Hours: osm.tags["opening_hours"] == "24/7"
            )
        }
    }

    private func fetchFuelStationsFromOSM(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) async throws -> [POIImportData] {

        let query = """
        [out:json][timeout:60];
        (
          node["amenity"="fuel"]["hgv:lanes"](\(minLat),\(minLon),\(maxLat),\(maxLon));
          node["amenity"="fuel"]["fuel:HGV_diesel"="yes"](\(minLat),\(minLon),\(maxLat),\(maxLon));
        );
        out center tags;
        """

        let results = try await executeOverpassQuery(query)
        return results.map { osm in
            POIImportData(
                type: .fuelStation,
                name: osm.tags["name"] ?? osm.tags["brand"] ?? "Fuel Station",
                address: osm.tags["addr:street"],
                city: osm.tags["addr:city"],
                state: osm.tags["addr:state"],
                zipCode: osm.tags["addr:postcode"],
                latitude: osm.lat,
                longitude: osm.lon,
                phone: osm.tags["phone"],
                website: osm.tags["website"],
                amenities: ["diesel", "parking"],
                brands: extractBrands(from: osm.tags),
                isOpen24Hours: osm.tags["opening_hours"] == "24/7"
            )
        }
    }

    // MARK: - Execute Overpass Query

    private func executeOverpassQuery(_ query: String) async throws -> [POIOverpassElement] {

        guard let url = URL(string: overpassAPIURL) else {
            throw NSError(domain: "POIImportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(query)".data(using: .utf8)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "POIImportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(POIOverpassResponse.self, from: data)

        print("📍 Fetched \(result.elements.count) elements from Overpass API")

        return result.elements
    }

    // MARK: - Upload to Supabase

    private func uploadPOIsToSupabase(_ pois: [POIImportData], progressHandler: @escaping (String, Int, Int) -> Void) async throws {

        print("☁️ Uploading \(pois.count) POIs to Supabase...")

        // Upload in batches of 50
        let batchSize = 50
        let batches = stride(from: 0, to: pois.count, by: batchSize).map {
            Array(pois[$0..<min($0 + batchSize, pois.count)])
        }

        for (index, batch) in batches.enumerated() {
            progressHandler("Uploading batch \(index + 1) of \(batches.count)", index, batches.count)

            // Convert to POI insert models
            let poiModels = batch.map { data -> POIInsertData in
                POIInsertData(
                    type: data.type.rawValue,
                    name: data.name,
                    address: data.address,
                    city: data.city,
                    state: data.state,
                    zip_code: data.zipCode,
                    latitude: data.latitude,
                    longitude: data.longitude,
                    phone: data.phone,
                    website: data.website,
                    amenities: data.amenities,
                    brands: data.brands,
                    is_open_24_hours: data.isOpen24Hours
                )
            }

            // Insert into Supabase (using upsert to avoid duplicates)
            do {
                try await SupabaseService.shared.client
                    .from("pois")
                    .upsert(poiModels)
                    .execute()

                print("✅ Uploaded batch \(index + 1)/\(batches.count) (\(batch.count) POIs)")
            } catch {
                print("❌ Failed to upload batch \(index + 1): \(error.localizedDescription)")
            }

            // Delay to avoid rate limiting
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        print("✅ Upload complete! Total POIs uploaded: \(pois.count)")
    }

    // MARK: - Helper Functions

    private func extractAmenities(from tags: [String: String]) -> [String] {
        var amenities: [String] = []

        // Check for common amenities in OSM tags
        if tags["fuel:diesel"] == "yes" || tags["fuel:HGV_diesel"] == "yes" { amenities.append("diesel") }
        if tags["amenity"] == "shower" || tags["shower"] == "yes" { amenities.append("showers") }
        if tags["amenity"] == "toilets" || tags["toilets"] == "yes" { amenities.append("restrooms") }
        if tags["internet_access"] == "wlan" || tags["wifi"] == "yes" { amenities.append("wifi") }
        if tags["amenity"] == "restaurant" { amenities.append("restaurant") }
        if tags["amenity"] == "fast_food" { amenities.append("fast_food") }
        if tags["amenity"] == "parking" || tags["parking"] == "yes" { amenities.append("parking") }
        if tags["hgv"] == "yes" { amenities.append("parking") }
        if tags["amenity"] == "weighbridge" { amenities.append("scales") }
        if tags["shop"] == "convenience" { amenities.append("store") }
        if tags["atm"] == "yes" { amenities.append("atm") }

        return amenities
    }

    private func extractBrands(from tags: [String: String]) -> [String]? {
        if let brand = tags["brand"] {
            return [brand]
        }
        if let operator_ = tags["operator"] {
            return [operator_]
        }
        return nil
    }
}

// MARK: - Data Models

struct POIImportData {
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
    let isOpen24Hours: Bool
}

// MARK: - Overpass API Response Models

struct POIOverpassResponse: Codable {
    let elements: [POIOverpassElement]
}

struct POIOverpassElement: Codable {
    let type: String
    let id: Int64
    let lat: Double
    let lon: Double
    let tags: [String: String]

    enum CodingKeys: String, CodingKey {
        case type, id, lat, lon, tags
    }

    // Handle both nodes and ways (ways have center point)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        id = try container.decode(Int64.self, forKey: .id)

        // For ways, lat/lon are in a "center" object
        if type == "way" {
            let centerContainer = try? decoder.container(keyedBy: CenterKeys.self)
            lat = try centerContainer?.decode(Double.self, forKey: .lat) ?? 0.0
            lon = try centerContainer?.decode(Double.self, forKey: .lon) ?? 0.0
        } else {
            lat = try container.decode(Double.self, forKey: .lat)
            lon = try container.decode(Double.self, forKey: .lon)
        }

        tags = try container.decodeIfPresent([String: String].self, forKey: .tags) ?? [:]
    }

    private enum CenterKeys: String, CodingKey {
        case lat, lon
    }
}

// MARK: - Supabase Insert Model

struct POIInsertData: Encodable {
    let type: String
    let name: String
    let address: String?
    let city: String?
    let state: String?
    let zip_code: String?
    let latitude: Double
    let longitude: Double
    let phone: String?
    let website: String?
    let amenities: [String]
    let brands: [String]?
    let is_open_24_hours: Bool
}
