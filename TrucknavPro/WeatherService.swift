//
//  WeatherService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation

struct WeatherData: Codable {
    let main: Main
    let weather: [Weather]

    struct Main: Codable {
        let temp: Double
    }

    struct Weather: Codable {
        let id: Int
        let main: String
        let description: String
    }
}

class WeatherService {

    static let shared = WeatherService()

    private init() {}

    private var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["OpenWeatherAPIKey"] as? String else {
            print("⚠️ OpenWeatherAPIKey not found in Info.plist")
            return ""
        }
        return key
    }

    func fetchWeather(for coordinate: CLLocationCoordinate2D, completion: @escaping (Result<(temperature: Int, symbolName: String), Error>) -> Void) {

        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])))
            return
        }

        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
                let temperature = Int(weatherData.main.temp)
                let weatherId = weatherData.weather.first?.id ?? 800
                let symbolName = self.weatherSymbol(for: weatherId)

                DispatchQueue.main.async {
                    completion(.success((temperature: temperature, symbolName: symbolName)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func weatherSymbol(for conditionId: Int) -> String {
        // OpenWeather condition codes: https://openweathermap.org/weather-conditions
        switch conditionId {
        case 200...232: // Thunderstorm
            return "cloud.bolt.rain.fill"
        case 300...321: // Drizzle
            return "cloud.drizzle.fill"
        case 500...531: // Rain
            return "cloud.rain.fill"
        case 600...622: // Snow
            return "cloud.snow.fill"
        case 701...781: // Atmosphere (fog, mist, etc.)
            return "cloud.fog.fill"
        case 800: // Clear
            return "sun.max.fill"
        case 801: // Few clouds
            return "cloud.sun.fill"
        case 802...804: // Clouds
            return "cloud.fill"
        default:
            return "cloud.fill"
        }
    }
}
