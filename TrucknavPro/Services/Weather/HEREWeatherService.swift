//
//  HEREWeatherService.swift
//  TruckNavPro
//
//  HERE Destination Weather API - Weather forecasts along routes
//

import Foundation
import CoreLocation

class HEREWeatherService {

    private let apiKey: String
    private let weatherURL = "https://weather.hereapi.com/v3"

    // Fast URLSession with short timeout for better performance
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12.0  // 8 second timeout
        config.timeoutIntervalForResource = 20.0  // 15 second total timeout
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    struct WeatherConditions {
        let location: CLLocationCoordinate2D
        let temperature: Double         // Fahrenheit (converted from Celsius)
        let feelsLike: Double          // Fahrenheit
        let humidity: Double           // 0-100%
        let windSpeed: Double          // mph (converted from m/s)
        let windDirection: Int         // degrees
        let visibility: Double         // miles (converted from meters)
        let precipitation: Double      // inches per hour
        let description: String
        let iconName: String
        let condition: WeatherCondition
        let alerts: [WeatherAlert]?

        enum WeatherCondition: String {
            case clear = "Clear"
            case cloudy = "Cloudy"
            case partlyCloudy = "Partly Cloudy"
            case rain = "Rain"
            case snow = "Snow"
            case fog = "Fog"
            case thunderstorm = "Thunderstorm"
            case heavyRain = "Heavy Rain"
            case icyConditions = "Icy Conditions"
            case unknown = "Unknown"

            var isSevere: Bool {
                switch self {
                case .thunderstorm, .heavyRain, .snow, .icyConditions, .fog:
                    return true
                default:
                    return false
                }
            }

            var emoji: String {
                switch self {
                case .clear: return "☀️"
                case .cloudy: return "☁️"
                case .partlyCloudy: return "⛅"
                case .rain: return "🌧️"
                case .snow: return "❄️"
                case .fog: return "🌫️"
                case .thunderstorm: return "⛈️"
                case .heavyRain: return "🌧️"
                case .icyConditions: return "🧊"
                case .unknown: return "🌡️"
                }
            }
        }

        struct WeatherAlert {
            let type: String
            let severity: String
            let description: String
            let startTime: Date?
            let endTime: Date?
        }
    }

    struct HourlyForecast {
        let time: Date
        let temperature: Double         // Fahrenheit
        let precipitation: Double       // inches per hour
        let condition: WeatherConditions.WeatherCondition
        let windSpeed: Double          // mph
    }

    init(apiKey: String) {
        self.apiKey = apiKey
        print("🌤️ HERE Weather Service initialized with API key: \(apiKey.prefix(10))...")
    }

    // MARK: - Current Weather

    func getCurrentWeather(
        at coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<WeatherConditions, Error>) -> Void
    ) {
        let urlString = "\(weatherURL)/report?apiKey=\(apiKey)&location=\(coordinate.latitude),\(coordinate.longitude)&product=observation&oneobservation=true&metric=false"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "HEREWeather", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🌤️ HERE Weather: Current conditions at \(coordinate)")
        print("🌐 URL: \(url.absoluteString)")

        urlSession.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Weather error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HERE Weather response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorMsg = "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    completion(.failure(NSError(domain: "HEREWeather", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
            }

            guard let data = data else {
                print("❌ HERE Weather: No data received")
                completion(.failure(NSError(domain: "HEREWeather", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response preview
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 HERE Weather response preview: \(jsonString.prefix(500))...")
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(HEREWeatherResponse.self, from: data)

                guard let observation = response.observations?.location.first?.observation.first else {
                    completion(.failure(NSError(domain: "HEREWeather", code: -3, userInfo: [NSLocalizedDescriptionKey: "No weather data available"])))
                    return
                }

                // Convert to imperial units (app standard)
                let tempF = (observation.temperature ?? 0) * 9/5 + 32
                // If comfort (feels like) is available in Celsius, convert it; otherwise use actual temp
                let feelsLikeF = (observation.comfort ?? observation.temperature ?? 0) * 9/5 + 32
                let windMph = (observation.windSpeed ?? 0) * 2.237
                let visibilityMiles = (observation.visibility ?? 0) / 1609.34
                let precipInches = (observation.precipitation1H ?? 0) / 25.4

                let condition = self.mapWeatherCondition(description: observation.description ?? "", iconName: observation.iconName ?? "")

                let weather = WeatherConditions(
                    location: coordinate,
                    temperature: tempF,
                    feelsLike: feelsLikeF,
                    humidity: observation.humidity ?? 0,
                    windSpeed: windMph,
                    windDirection: observation.windDirection ?? 0,
                    visibility: visibilityMiles,
                    precipitation: precipInches,
                    description: observation.description ?? "Unknown",
                    iconName: observation.iconName ?? "",
                    condition: condition,
                    alerts: nil  // Alerts would come from separate endpoint
                )

                print("✅ HERE Weather: \(String(format: "%.0f", tempF))°F, \(condition.rawValue)")
                if condition.isSevere {
                    print("⚠️ SEVERE WEATHER ALERT: \(condition.rawValue)")
                }

                completion(.success(weather))
            } catch {
                print("❌ HERE Weather decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Weather Along Route

    func getWeatherAlongRoute(
        polyline: String,
        completion: @escaping (Result<[WeatherConditions], Error>) -> Void
    ) {
        // HERE Weather along route - sample points from polyline
        let urlString = "\(weatherURL)/report?apiKey=\(apiKey)&route=\(polyline)&product=observation&metric=false"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "HEREWeather", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🌤️ HERE Weather: Along route")

        urlSession.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Weather (route) error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "HEREWeather", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(HEREWeatherResponse.self, from: data)

                var weatherPoints: [WeatherConditions] = []

                if let locations = response.observations?.location {
                    for location in locations {
                        if let observation = location.observation.first {
                            let coord = CLLocationCoordinate2D(
                                latitude: location.latitude ?? 0,
                                longitude: location.longitude ?? 0
                            )

                            let tempF = (observation.temperature ?? 0) * 9/5 + 32
                            let feelsLikeF = (observation.comfort ?? tempF - 32) * 9/5 + 32
                            let windMph = (observation.windSpeed ?? 0) * 2.237
                            let visibilityMiles = (observation.visibility ?? 0) / 1609.34
                            let precipInches = (observation.precipitation1H ?? 0) / 25.4

                            let condition = self.mapWeatherCondition(description: observation.description ?? "", iconName: observation.iconName ?? "")

                            let weather = WeatherConditions(
                                location: coord,
                                temperature: tempF,
                                feelsLike: feelsLikeF,
                                humidity: observation.humidity ?? 0,
                                windSpeed: windMph,
                                windDirection: observation.windDirection ?? 0,
                                visibility: visibilityMiles,
                                precipitation: precipInches,
                                description: observation.description ?? "Unknown",
                                iconName: observation.iconName ?? "",
                                condition: condition,
                                alerts: nil
                            )

                            weatherPoints.append(weather)
                        }
                    }
                }

                print("✅ HERE Weather (route): \(weatherPoints.count) points")
                completion(.success(weatherPoints))
            } catch {
                print("❌ HERE Weather (route) decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Hourly Forecast

    func getHourlyForecast(
        at coordinate: CLLocationCoordinate2D,
        hours: Int = 24,
        completion: @escaping (Result<[HourlyForecast], Error>) -> Void
    ) {
        let urlString = "\(weatherURL)/report?apiKey=\(apiKey)&location=\(coordinate.latitude),\(coordinate.longitude)&product=forecast_hourly&metric=false"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "HEREWeather", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🌤️ HERE Weather: Hourly forecast at \(coordinate)")

        urlSession.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Weather (forecast) error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "HEREWeather", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(HEREWeatherForecastResponse.self, from: data)

                var forecasts: [HourlyForecast] = []

                if let location = response.forecasts?.location.first {
                    for forecast in location.forecast.prefix(hours) {
                        let tempF = (forecast.temperature ?? 0) * 9/5 + 32
                        let windMph = (forecast.windSpeed ?? 0) * 2.237
                        let precipInches = (forecast.precipitation1H ?? 0) / 25.4
                        let condition = self.mapWeatherCondition(description: forecast.description ?? "", iconName: forecast.iconName ?? "")

                        let hourly = HourlyForecast(
                            time: Date(timeIntervalSince1970: TimeInterval(forecast.utcTime ?? 0)),
                            temperature: tempF,
                            precipitation: precipInches,
                            condition: condition,
                            windSpeed: windMph
                        )

                        forecasts.append(hourly)
                    }
                }

                print("✅ HERE Weather (forecast): \(forecasts.count) hours")
                completion(.success(forecasts))
            } catch {
                print("❌ HERE Weather (forecast) decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Helper Functions

    private func mapWeatherCondition(description: String, iconName: String) -> WeatherConditions.WeatherCondition {
        let desc = description.lowercased()

        if desc.contains("thunderstorm") || desc.contains("severe") {
            return .thunderstorm
        } else if desc.contains("heavy rain") || desc.contains("downpour") {
            return .heavyRain
        } else if desc.contains("rain") || desc.contains("shower") {
            return .rain
        } else if desc.contains("snow") || desc.contains("blizzard") {
            return .snow
        } else if desc.contains("fog") || desc.contains("mist") {
            return .fog
        } else if desc.contains("ice") || desc.contains("freezing") {
            return .icyConditions
        } else if desc.contains("cloudy") || desc.contains("overcast") {
            return .cloudy
        } else if desc.contains("partly") || desc.contains("scattered") {
            return .partlyCloudy
        } else if desc.contains("clear") || desc.contains("sunny") {
            return .clear
        }

        return .unknown
    }
}

// MARK: - Response Models

struct HEREWeatherResponse: Codable {
    let observations: Observations?

    struct Observations: Codable {
        let location: [Location]

        struct Location: Codable {
            let latitude: Double?
            let longitude: Double?
            let observation: [Observation]

            struct Observation: Codable {
                let temperature: Double?
                let comfort: Double?
                let humidity: Double?
                let windSpeed: Double?
                let windDirection: Int?
                let visibility: Double?
                let precipitation1H: Double?
                let description: String?
                let iconName: String?
                let daylight: String?
                let skyInfo: String?
            }
        }
    }
}

struct HEREWeatherForecastResponse: Codable {
    let forecasts: Forecasts?

    struct Forecasts: Codable {
        let location: [Location]

        struct Location: Codable {
            let latitude: Double?
            let longitude: Double?
            let forecast: [Forecast]

            struct Forecast: Codable {
                let utcTime: Int?
                let temperature: Double?
                let windSpeed: Double?
                let windDirection: Int?
                let precipitation1H: Double?
                let description: String?
                let iconName: String?
            }
        }
    }
}
