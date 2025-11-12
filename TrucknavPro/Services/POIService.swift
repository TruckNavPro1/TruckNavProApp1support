//
//  POIService.swift
//  TruckNavPro
//
//  Service for fetching and managing Points of Interest from Supabase

import Foundation
import CoreLocation
import Supabase

class POIService {

    static let shared = POIService()

    private let supabase = SupabaseService.shared
    private var cachedPOIs: [POI] = []
    private var lastFetchLocation: CLLocation?
    private var lastFetchTime: Date?

    // Cache settings
    private let cacheRadius: Double = 100_000  // 100km in meters
    private let cacheExpiration: TimeInterval = 3600  // 1 hour

    private init() {}

    // MARK: - Fetch POIs

    /// Fetch POIs near a specific location
    func fetchPOIsNear(
        location: CLLocation,
        radius: Double = 50_000,  // 50km default
        types: [POIType]? = nil,
        minRating: Double? = nil,
        amenities: [String]? = nil,
        forceRefresh: Bool = false
    ) async throws -> [POI] {

        // Check cache first
        if !forceRefresh, let cached = getCachedPOIs(near: location, radius: radius) {
            print("📍 Using cached POIs (\(cached.count) items)")
            return cached
        }

        print("📍 Fetching POIs from Supabase near \(location.coordinate.latitude), \(location.coordinate.longitude)")

        // Build parameters for RPC call
        let params = POINearLocationParams(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            radius_meters: Int(radius),
            poi_types: types?.map { $0.rawValue },
            min_rating: minRating,
            required_amenities: amenities
        )

        // Call Supabase RPC function
        let response: [POIResponse] = try await SupabaseService.shared.client
            .rpc("get_pois_near_location", params: params)
            .execute()
            .value

        // Convert to POI models
        let pois = response.map { $0.toPOI() }

        // Update cache
        cachedPOIs = pois
        lastFetchLocation = location
        lastFetchTime = Date()

        print("✅ Fetched \(pois.count) POIs from Supabase")
        return pois
    }

    /// Fetch POIs along a route
    func fetchPOIsAlongRoute(
        routeCoordinates: [CLLocationCoordinate2D],
        bufferMeters: Int = 5000,
        types: [POIType]? = nil
    ) async throws -> [POI] {

        print("📍 Fetching POIs along route with \(routeCoordinates.count) waypoints")

        // Convert coordinates to JSONB format
        let coordsJSON = routeCoordinates.map { coord in
            RouteCoord(lat: coord.latitude, lng: coord.longitude)
        }

        // Build parameters
        let params = POIAlongRouteParams(
            route_coords: coordsJSON,
            buffer_meters: bufferMeters,
            poi_types: types?.map { $0.rawValue }
        )

        // Call Supabase RPC function
        let response: [POIAlongRouteResponse] = try await SupabaseService.shared.client
            .rpc("get_pois_along_route", params: params)
            .execute()
            .value

        // Convert to POI models (simplified version from route query)
        let pois = response.compactMap { responsePOI -> POI? in
            POI(
                id: responsePOI.id.uuidString,
                type: POIType(rawValue: responsePOI.type) ?? .truckStop,
                name: responsePOI.name,
                address: nil,
                city: nil,
                state: nil,
                zipCode: nil,
                latitude: responsePOI.latitude,
                longitude: responsePOI.longitude,
                phone: nil,
                website: nil,
                amenities: responsePOI.amenities,
                brands: nil,
                rating: responsePOI.rating,
                reviewCount: nil,
                isOpen24Hours: false,
                operatingHours: nil,
                createdAt: nil,
                updatedAt: nil
            )
        }

        print("✅ Found \(pois.count) POIs along route")
        return pois
    }

    /// Fetch specific POI by ID with full details
    func fetchPOI(id: String) async throws -> POI {
        print("📍 Fetching POI details for \(id)")

        let response: [POI] = try await SupabaseService.shared.client
            .from("pois")
            .select()
            .eq("id", value: id)
            .execute()
            .value

        guard let poi = response.first else {
            throw NSError(domain: "POIService", code: 404, userInfo: [NSLocalizedDescriptionKey: "POI not found"])
        }

        print("✅ Fetched POI: \(poi.name)")
        return poi
    }

    // MARK: - Reviews

    /// Fetch reviews for a POI
    func fetchReviews(for poiId: String) async throws -> [POIReview] {
        print("📍 Fetching reviews for POI \(poiId)")

        let response: [POIReview] = try await SupabaseService.shared.client
            .from("poi_reviews")
            .select()
            .eq("poi_id", value: poiId)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("✅ Fetched \(response.count) reviews")
        return response
    }

    /// Submit a review for a POI
    func submitReview(
        poiId: String,
        rating: Double,
        comment: String?,
        amenityRatings: [String: Double]?
    ) async throws -> POIReview {

        guard let userId = try? await SupabaseService.shared.currentUser?.id.uuidString else {
            throw NSError(domain: "POIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let review = POIReview(
            id: UUID().uuidString,
            poiId: poiId,
            userId: userId,
            userName: nil,  // Can be fetched from profile
            rating: rating,
            comment: comment,
            amenityRatings: amenityRatings,
            createdAt: Date(),
            updatedAt: nil
        )

        let _: POIReview = try await SupabaseService.shared.client
            .from("poi_reviews")
            .insert(review)
            .execute()
            .value

        print("✅ Review submitted for POI \(poiId)")
        return review
    }

    // MARK: - Favorites

    /// Get user's favorite POIs
    func getFavorites() async throws -> [POI] {
        guard let userId = try? await SupabaseService.shared.currentUser?.id.uuidString else {
            throw NSError(domain: "POIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        print("📍 Fetching favorite POIs for user \(userId)")

        // First get favorite POI IDs
        let favoriteResponse: [UserFavoritePOI] = try await SupabaseService.shared.client
            .from("user_favorite_pois")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let poiIds = favoriteResponse.map { $0.poiId }

        guard !poiIds.isEmpty else {
            print("✅ No favorite POIs found")
            return []
        }

        // Fetch full POI details
        let poisResponse: [POI] = try await SupabaseService.shared.client
            .from("pois")
            .select()
            .in("id", values: poiIds)
            .execute()
            .value

        print("✅ Fetched \(poisResponse.count) favorite POIs")
        return poisResponse
    }

    /// Add POI to favorites
    func addToFavorites(poiId: String) async throws {
        guard let userId = try? await SupabaseService.shared.currentUser?.id.uuidString else {
            throw NSError(domain: "POIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let favorite = UserFavoritePOI(
            id: UUID().uuidString,
            userId: userId,
            poiId: poiId,
            createdAt: Date()
        )

        let _: UserFavoritePOI = try await SupabaseService.shared.client
            .from("user_favorite_pois")
            .insert(favorite)
            .execute()
            .value

        print("✅ Added POI \(poiId) to favorites")
    }

    /// Remove POI from favorites
    func removeFromFavorites(poiId: String) async throws {
        guard let userId = try? await SupabaseService.shared.currentUser?.id.uuidString else {
            throw NSError(domain: "POIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await SupabaseService.shared.client
            .from("user_favorite_pois")
            .delete()
            .eq("user_id", value: userId)
            .eq("poi_id", value: poiId)
            .execute()

        print("✅ Removed POI \(poiId) from favorites")
    }

    // MARK: - Cache Management

    private func getCachedPOIs(near location: CLLocation, radius: Double) -> [POI]? {
        // Check if cache is still valid
        guard let lastFetch = lastFetchTime,
              let lastLocation = lastFetchLocation,
              Date().timeIntervalSince(lastFetch) < cacheExpiration,
              lastLocation.distance(from: location) < cacheRadius else {
            return nil
        }

        // Filter cached POIs by requested radius
        return cachedPOIs.filter { poi in
            let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
            return location.distance(from: poiLocation) <= radius
        }
    }

    /// Clear the POI cache
    func clearCache() {
        cachedPOIs = []
        lastFetchLocation = nil
        lastFetchTime = nil
        print("🗑️ POI cache cleared")
    }
}

// MARK: - Response Models

struct POIResponse: Codable {
    let id: UUID
    let type: String
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
    let operatingHours: [String: String]?
    let distanceMeters: Double
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, name, address, city, state
        case zipCode = "zip_code"
        case latitude, longitude, phone, website, amenities, brands
        case rating
        case reviewCount = "review_count"
        case isOpen24Hours = "is_open_24_hours"
        case operatingHours = "operating_hours"
        case distanceMeters = "distance_meters"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toPOI() -> POI {
        POI(
            id: id.uuidString,
            type: POIType(rawValue: type) ?? .truckStop,
            name: name,
            address: address,
            city: city,
            state: state,
            zipCode: zipCode,
            latitude: latitude,
            longitude: longitude,
            phone: phone,
            website: website,
            amenities: amenities,
            brands: brands,
            rating: rating,
            reviewCount: reviewCount,
            isOpen24Hours: isOpen24Hours,
            operatingHours: operatingHours,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct POIAlongRouteResponse: Codable {
    let id: UUID
    let type: String
    let name: String
    let latitude: Double
    let longitude: Double
    let amenities: [String]
    let rating: Double?
    let distanceFromRoute: Double

    enum CodingKeys: String, CodingKey {
        case id, type, name, latitude, longitude, amenities, rating
        case distanceFromRoute = "distance_from_route"
    }
}

struct UserFavoritePOI: Codable {
    let id: String
    let userId: String
    let poiId: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case poiId = "poi_id"
        case createdAt = "created_at"
    }
}

// MARK: - RPC Parameter Models

struct POINearLocationParams: Encodable {
    let lat: Double
    let lng: Double
    let radius_meters: Int
    let poi_types: [String]?
    let min_rating: Double?
    let required_amenities: [String]?
}

struct RouteCoord: Encodable {
    let lat: Double
    let lng: Double
}

struct POIAlongRouteParams: Encodable {
    let route_coords: [RouteCoord]
    let buffer_meters: Int
    let poi_types: [String]?
}
