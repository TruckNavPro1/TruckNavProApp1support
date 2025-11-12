//
//  WeatherService.swift
//  TruckNavPro
//
//  Apple WeatherKit integration for live weather data
//

import Foundation
import CoreLocation
import WeatherKit

struct WeatherInfo {
    let temperature: Int
    let high: Int
    let low: Int
    let condition: String
    let symbolName: String
    let dayName: String
}

@available(iOS 16.0, *)
class WeatherService {

    static let shared = WeatherService()

    private let weatherService = WeatherKit.WeatherService()
    private var cachedWeather: (location: CLLocationCoordinate2D, weather: WeatherInfo, timestamp: Date)?
    private let cacheExpiration: TimeInterval = 600  // 10 minutes

    private init() {}

    /// Fetch current weather using Apple WeatherKit
    func fetchWeather(for coordinate: CLLocationCoordinate2D, completion: @escaping (Result<WeatherInfo, Error>) -> Void) {

        print("🌡️ WeatherService: Starting weather fetch")
        print("🌡️ WeatherKit entitlement enabled: Check Xcode project settings")

        // Check cache first
        if let cached = cachedWeather,
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration,
           areCoordinatesClose(cached.location, coordinate) {
            print("🌡️ Using cached weather data")
            completion(.success(cached.weather))
            return
        }

        Task {
            do {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

                print("🌡️ Calling WeatherKit API...")
                // Fetch current weather from WeatherKit
                let weather = try await weatherService.weather(for: location)
                print("🌡️ WeatherKit API response received")

                let currentWeather = weather.currentWeather
                let dailyForecast = weather.dailyForecast.first

                // Convert to our WeatherInfo model
                let temperature = Int(round(currentWeather.temperature.value))
                let high = dailyForecast?.highTemperature.value != nil ? Int(round(dailyForecast!.highTemperature.value)) : temperature + 5
                let low = dailyForecast?.lowTemperature.value != nil ? Int(round(dailyForecast!.lowTemperature.value)) : temperature - 5
                let condition = currentWeather.condition.description
                let symbolName = weatherSymbol(for: currentWeather.condition)

                let weatherInfo = WeatherInfo(
                    temperature: temperature,
                    high: high,
                    low: low,
                    condition: condition,
                    symbolName: symbolName,
                    dayName: currentDayName()
                )

                // Cache the result
                self.cachedWeather = (coordinate, weatherInfo, Date())

                print("🌡️ WeatherKit data received:")
                print("   Temperature: \(temperature)°F")
                print("   High: \(high)°F, Low: \(low)°F")
                print("   Condition: \(condition)")

                DispatchQueue.main.async {
                    completion(.success(weatherInfo))
                }

            } catch {
                print("❌ WeatherKit error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")

                // Fallback to cached data if available
                if let cached = cachedWeather {
                    print("⚠️ Using stale cached data due to error")
                    DispatchQueue.main.async {
                        completion(.success(cached.weather))
                    }
                } else {
                    // Fallback to OpenWeather API
                    print("⚠️ WeatherKit not available - falling back to OpenWeather API")
                    self.fetchFromOpenWeather(coordinate: coordinate, completion: completion)
                }
            }
        }
    }

    /// Fallback to OpenWeather API when WeatherKit is not available
    private func fetchFromOpenWeather(coordinate: CLLocationCoordinate2D, completion: @escaping (Result<WeatherInfo, Error>) -> Void) {
        guard let apiKey = Bundle.main.infoDictionary?["OpenWeatherKey"] as? String,
              !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" else {
            print("⚠️ OpenWeather API key not configured - using mock data")
            let mockWeather = WeatherInfo(
                temperature: 72,
                high: 78,
                low: 65,
                condition: "Weather Unavailable",
                symbolName: "cloud.sun.fill",
                dayName: currentDayName()
            )
            completion(.success(mockWeather))
            return
        }

        print("🌐 Fetching weather from OpenWeather API...")
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ OpenWeather API error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                struct OpenWeatherResponse: Codable {
                    struct Main: Codable {
                        let temp: Double
                        let tempMin: Double
                        let tempMax: Double

                        enum CodingKeys: String, CodingKey {
                            case temp
                            case tempMin = "temp_min"
                            case tempMax = "temp_max"
                        }
                    }
                    struct Weather: Codable {
                        let id: Int
                        let main: String
                        let description: String
                    }
                    let main: Main
                    let weather: [Weather]
                }

                let weatherData = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
                let temperature = Int(round(weatherData.main.temp))
                let high = Int(round(weatherData.main.tempMax))
                let low = Int(round(weatherData.main.tempMin))
                let condition = weatherData.weather.first?.description.capitalized ?? "Unknown"
                let weatherId = weatherData.weather.first?.id ?? 800
                let symbolName = self.openWeatherSymbol(for: weatherId)

                let weatherInfo = WeatherInfo(
                    temperature: temperature,
                    high: high,
                    low: low,
                    condition: condition,
                    symbolName: symbolName,
                    dayName: self.currentDayName()
                )

                // Cache the result
                self.cachedWeather = (coordinate, weatherInfo, Date())

                print("✅ OpenWeather data received: \(temperature)°F \(condition)")
                DispatchQueue.main.async {
                    completion(.success(weatherInfo))
                }
            } catch {
                print("❌ OpenWeather decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func openWeatherSymbol(for conditionId: Int) -> String {
        switch conditionId {
        case 200...232: return "cloud.bolt.rain.fill"
        case 300...321: return "cloud.drizzle.fill"
        case 500...531: return "cloud.rain.fill"
        case 600...622: return "cloud.snow.fill"
        case 701...781: return "cloud.fog.fill"
        case 800: return "sun.max.fill"
        case 801: return "cloud.sun.fill"
        case 802...804: return "cloud.fill"
        default: return "cloud.fill"
        }
    }

    /// Fetch hourly forecast for next 24 hours
    func fetchHourlyForecast(for coordinate: CLLocationCoordinate2D) async throws -> [HourWeather] {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let weather = try await weatherService.weather(for: location)
        return Array(weather.hourlyForecast.prefix(24))
    }

    /// Fetch daily forecast for next 10 days
    func fetchDailyForecast(for coordinate: CLLocationCoordinate2D) async throws -> [DayWeather] {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let weather = try await weatherService.weather(for: location)
        return Array(weather.dailyForecast.prefix(10))
    }

    /// Clear cached weather data
    func clearCache() {
        cachedWeather = nil
        print("🗑️ Weather cache cleared")
    }

    // MARK: - Private Helpers

    private func currentDayName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full day name
        return formatter.string(from: Date())
    }

    private func areCoordinatesClose(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Bool {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2) < 10000  // Within 10km
    }

    private func weatherSymbol(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear:
            return "sun.max.fill"
        case .cloudy:
            return "cloud.fill"
        case .mostlyClear:
            return "cloud.sun.fill"
        case .mostlyCloudy:
            return "cloud.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .foggy:
            return "cloud.fog.fill"
        case .haze:
            return "sun.haze.fill"
        case .smoky:
            return "smoke.fill"
        case .drizzle:
            return "cloud.drizzle.fill"
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .flurries:
            return "cloud.snow.fill"
        case .sleet:
            return "cloud.sleet.fill"
        case .hail:
            return "cloud.hail.fill"
        case .freezingRain:
            return "cloud.sleet.fill"
        case .freezingDrizzle:
            return "cloud.drizzle.fill"
        case .thunderstorms:
            return "cloud.bolt.rain.fill"
        case .strongStorms:
            return "cloud.bolt.fill"
        case .tropicalStorm:
            return "tropicalstorm"
        case .hurricane:
            return "hurricane"
        case .blizzard:
            return "wind.snow"
        case .blowingDust:
            return "sun.dust.fill"
        case .blowingSnow:
            return "wind.snow"
        case .breezy:
            return "wind"
        case .windy:
            return "wind"
        case .hot:
            return "thermometer.sun.fill"
        case .frigid:
            return "thermometer.snowflake"
        @unknown default:
            return "cloud.fill"
        }
    }
}

// MARK: - iOS 15 Fallback

/// Fallback for iOS 15 (WeatherKit requires iOS 16+)
@available(iOS, deprecated: 16.0, message: "Use WeatherKit on iOS 16+")
class LegacyWeatherService {

    static let shared = LegacyWeatherService()

    private init() {}

    func fetchWeather(for coordinate: CLLocationCoordinate2D, completion: @escaping (Result<WeatherInfo, Error>) -> Void) {
        // Return mock data for iOS 15
        let mockWeather = WeatherInfo(
            temperature: 72,
            high: 78,
            low: 65,
            condition: "Partly Cloudy",
            symbolName: "cloud.sun.fill",
            dayName: currentDayName()
        )
        DispatchQueue.main.async {
            completion(.success(mockWeather))
        }
    }

    private func currentDayName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
}
