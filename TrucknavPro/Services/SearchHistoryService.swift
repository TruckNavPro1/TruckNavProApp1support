//
//  SearchHistoryService.swift
//  TruckNavPro
//
//  Search history and favorites management
//

import Foundation
import CoreLocation

struct SavedLocation: Codable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    var isFavorite: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: String = UUID().uuidString, name: String, address: String? = nil, coordinate: CLLocationCoordinate2D, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = Date()
        self.isFavorite = isFavorite
    }
}

class SearchHistoryService {

    static let shared = SearchHistoryService()

    private let userDefaults = UserDefaults.standard
    private let recentSearchesKey = "recentSearches"
    private let favoritesKey = "favorites"
    private let maxRecentSearches = 20

    private init() {}

    // MARK: - Recent Searches

    func addRecentSearch(name: String, address: String?, coordinate: CLLocationCoordinate2D) {
        var recents = getRecentSearches()

        // Remove duplicate if exists (same name or very close coordinate)
        recents.removeAll { saved in
            saved.name == name || saved.coordinate.distance(to: coordinate) < 10
        }

        // Add new search at the beginning
        let newSearch = SavedLocation(name: name, address: address, coordinate: coordinate)
        recents.insert(newSearch, at: 0)

        // Keep only max recent searches
        if recents.count > maxRecentSearches {
            recents = Array(recents.prefix(maxRecentSearches))
        }

        saveRecentSearches(recents)
        print("💾 Added recent search: \(name)")
    }

    func getRecentSearches() -> [SavedLocation] {
        guard let data = userDefaults.data(forKey: recentSearchesKey) else { return [] }
        guard let searches = try? JSONDecoder().decode([SavedLocation].self, from: data) else { return [] }
        return searches
    }

    func clearRecentSearches() {
        userDefaults.removeObject(forKey: recentSearchesKey)
        print("🗑️ Cleared recent searches")
    }

    private func saveRecentSearches(_ searches: [SavedLocation]) {
        guard let data = try? JSONEncoder().encode(searches) else { return }
        userDefaults.set(data, forKey: recentSearchesKey)
    }

    // MARK: - Favorites

    func addFavorite(name: String, address: String?, coordinate: CLLocationCoordinate2D) {
        var favorites = getFavorites()

        // Check if already favorited
        if favorites.contains(where: { $0.name == name || $0.coordinate.distance(to: coordinate) < 10 }) {
            print("⭐ Already in favorites: \(name)")
            return
        }

        // Add new favorite
        var newFavorite = SavedLocation(name: name, address: address, coordinate: coordinate)
        newFavorite.isFavorite = true
        favorites.append(newFavorite)

        saveFavorites(favorites)
        print("⭐ Added favorite: \(name)")
    }

    func removeFavorite(id: String) {
        var favorites = getFavorites()
        favorites.removeAll { $0.id == id }
        saveFavorites(favorites)
        print("💔 Removed favorite")
    }

    func getFavorites() -> [SavedLocation] {
        guard let data = userDefaults.data(forKey: favoritesKey) else { return [] }
        guard let favorites = try? JSONDecoder().decode([SavedLocation].self, from: data) else { return [] }
        return favorites
    }

    func isFavorite(coordinate: CLLocationCoordinate2D) -> Bool {
        let favorites = getFavorites()
        return favorites.contains { $0.coordinate.distance(to: coordinate) < 10 }
    }

    private func saveFavorites(_ favorites: [SavedLocation]) {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        userDefaults.set(data, forKey: favoritesKey)
    }

    // MARK: - Combined Search

    func getCombinedSearches() -> (favorites: [SavedLocation], recents: [SavedLocation]) {
        return (getFavorites(), getRecentSearches())
    }
}
