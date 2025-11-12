# HERE Search API Integration

## Overview

HERE Search API is now integrated as a **fallback** for TomTom Search. When TomTom search fails (due to API errors, rate limits, or invalid keys), the app automatically falls back to HERE Search.

## How It Works

### Search Flow
1. **Primary**: TomTom Search is tried first (if API key is available)
2. **Fallback**: If TomTom fails, HERE Search is automatically used
3. **User Experience**: Seamless transition - users won't notice which service is being used

### Current Configuration

```
API Key: dGu8jMa7E30gI4W96PFv
Added to: Info.plist → HEREAPIKey
```

## Features

### Text Search
- Free-form text queries (e.g., "gas station near me", "truck stop")
- Location-based results (sorted by distance)
- Up to 50 results per query

### Category Search
Supports truck-specific categories:
- Truck Stops
- Rest Areas
- Weigh Stations
- Truck Parking
- Fuel Stations
- Repair Shops
- Hotels
- Restaurants

## API Details

### Endpoint
**Current**: Geocode API (more widely compatible)
```
https://geocode.search.hereapi.com/v1/geocode
```

**Alternative**: Discover API (requires specific API tier)
```
https://discover.search.hereapi.com/v1/discover
```

### Query Parameters
- `q`: Search query text
- `at`: Latitude,Longitude of user's location (optional, improves results)
- `limit`: Number of results (default: 10, max: 50)
- `apiKey`: HERE API key

### Example Request
```
GET https://geocode.search.hereapi.com/v1/geocode?q=truck%20stop&at=37.7749,-122.4194&limit=20&apiKey=dGu8jMa7E30gI4W96PFv
```

### Response Format
```json
{
  "items": [
    {
      "id": "here:pds:place:...",
      "title": "TA Travel Center",
      "position": {
        "lat": 37.7749,
        "lng": -122.4194
      },
      "distance": 1234,
      "address": {
        "label": "123 Main St, San Francisco, CA 94102"
      },
      "categories": [
        {
          "id": "700-7600-0116",
          "name": "Truck Stop"
        }
      ]
    }
  ]
}
```

## Files Modified

### 1. HERESearchService.swift (NEW)
Location: `TrucknavPro/Services/Search/HERESearchService.swift`

Main class for HERE API integration:
```swift
class HERESearchService {
    func searchText(_ query: String, near: CLLocationCoordinate2D, limit: Int, completion: ...)
    func searchCategory(_ category: TruckCategory, near: CLLocationCoordinate2D, radius: Int, limit: Int, completion: ...)
}
```

### 2. MapViewController+CustomSearch.swift
Updated search logic:
```swift
func performTextSearch(query: String) {
    // Try TomTom first
    if let tomTomService = tomTomSearchService {
        tomTomService.searchText(...) { result in
            switch result {
            case .success: // Show results
            case .failure: // Fall back to HERE
                self.tryHERESearchFallback(...)
            }
        }
    } else {
        // TomTom not available - try HERE directly
        tryHERESearchFallback(...)
    }
}

private func tryHERESearchFallback(...) {
    guard let hereService = hereSearchService else {
        // Neither service available - show error
        return
    }

    hereService.searchText(...) { result in
        // Convert HERE results to TomTom format for compatibility
        let results = hereResults.map { ... }
        showSearchResults(results, ...)
    }
}
```

### 3. NavigationViewController.swift
Added HERE initialization:
```swift
// TomTom Services (lines 74-77)
var tomTomSearchService: TomTomSearchService?

// HERE Services (Fallback) (lines 79-80)
var hereSearchService: HERESearchService?

// viewDidLoad (lines 177-186)
if let hereApiKey = Bundle.main.infoDictionary?["HEREAPIKey"] as? String {
    hereSearchService = HERESearchService(apiKey: hereApiKey)
    print("✅ HERE Search Service initialized (fallback enabled)")
}
```

### 4. Info.plist
Added HERE API key:
```xml
<key>HEREAPIKey</key>
<string>dGu8jMa7E30gI4W96PFv</string>
```

## Console Output

When the app runs, you'll see initialization messages:

### TomTom Available
```
🔑 Found TomTom API key: Nq78WMNfP...
✅ TomTom Services initialized successfully:
   - Search: ✓
🔑 Found HERE API key: dGu8jMa7E...
✅ HERE Search Service initialized (fallback enabled)
```

### Search Flow
```
🔍 Searching for: gas station near 37.7749, -122.4194
🗺️ Trying TomTom Search...
❌ TomTom search failed: HTTP 403
🗺️ Falling back to HERE Search...
🌐 URL: https://discover.search.hereapi.com/v1/discover?q=gas%20station&at=37.7749,-122.4194&limit=50&apiKey=dGu8jMa7E...
📡 HERE Response status: 200
✅ HERE Search returned 15 results
```

## API Quota & Limits

### HERE Free Tier
- **Free requests**: Check at [developer.here.com](https://developer.here.com/)
- **Rate limits**: Typically higher than TomTom's 2,500/day
- **Geographic coverage**: Worldwide
- **No domain restrictions**: Works from any app/domain

### Optimization Tips
1. Use TomTom as primary (already has quota)
2. HERE only activates when TomTom fails
3. This dual-API approach maximizes availability and quota

## Error Handling

### If TomTom Fails
- Automatic fallback to HERE
- User sees one error message (if both fail)
- Logs show which service was attempted

### If Both Fail
```
Alert: "Search Error"
Message: "Both TomTom and HERE Search failed.

TomTom: HTTP 403 - Forbidden
HERE: HTTP 429 - Rate limit exceeded

Check API keys at:
https://developer.tomtom.com/
https://developer.here.com/"
```

### Network Errors
```
Alert: "Search Error"
Message: "No internet connection. Please check your network settings."
```

## Getting a HERE API Key

1. Visit [developer.here.com](https://developer.here.com/)
2. Sign up for free account
3. Create new project
4. Generate API key for "Geocoding & Search API"
5. Copy key to Info.plist → HEREAPIKey

## Testing

### Test TomTom Primary
1. Run app
2. Search for "truck stop"
3. Console should show: "🗺️ Trying TomTom Search..."
4. If succeeds: Results displayed
5. If fails: Auto-fallback to HERE

### Test HERE Fallback
1. Temporarily remove TomTom API key from Info.plist
2. Search for "rest area"
3. Console should show: "⚠️ TomTom not available, trying HERE Search..."
4. HERE results should display

### Test Both Failing
1. Set both API keys to invalid values
2. Search for anything
3. Should see comprehensive error message with both failure reasons

## Production Checklist

- [x] HERE API key added to Info.plist
- [x] HERESearchService.swift created
- [x] Fallback logic implemented in MapViewController+CustomSearch
- [x] NavigationViewController initializes HERE service
- [x] Error messages updated for dual-API scenario
- [x] Console logging for debugging
- [x] Build succeeds

## Next Steps (Optional)

1. **Monitor API Usage**: Check TomTom vs HERE usage in analytics
2. **Adjust Fallback Logic**: Could add HERE as primary if TomTom quota exhausted
3. **Add More Services**: Could add Google Places, Mapbox Search as tertiary fallbacks
4. **Cache Results**: Reduce API calls by caching recent searches

## Support

- TomTom Docs: [developer.tomtom.com/search-api](https://developer.tomtom.com/search-api)
- HERE Docs: [developer.here.com/documentation/geocoding-search-api/dev_guide/index.html](https://developer.here.com/documentation/geocoding-search-api/dev_guide/index.html)
- Issues: Report in TruckNavPro project issues

---

**Status**: ✅ Implemented and Tested
**Build**: SUCCESS
**Last Updated**: 2025-11-11
