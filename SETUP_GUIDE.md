# TruckNavPro Setup Guide

## ✅ What's Been Implemented

### Hybrid Approach:
- **Mapbox**: Map display & search (geocoding)
- **TomTom**: Truck routing with proper restrictions

### Truck Parameters Included:
- ✅ Vehicle weight (18,000 kg default)
- ✅ Axle weight (7,000 kg)
- ✅ Dimensions: Length (16.5m), Width (2.5m), Height (4.0m)
- ✅ Commercial vehicle flag
- ✅ Hazmat cargo support (ready to configure)

## 🔧 Setup Steps

### 1. Add API Keys to Info.plist

Open `Info.plist` and add both keys:

```xml
<!-- Mapbox for maps & search -->
<key>MBXAccessToken</key>
<string>pk.ey...</string>

<!-- TomTom for truck routing -->
<key>TomTomAPIKey</key>
<string>YOUR_TOMTOM_API_KEY_HERE</string>
```

### 2. Get Your TomTom API Key

1. Go to: https://developer.tomtom.com/
2. Sign up / Log in
3. Go to Dashboard → My Apps
4. Create new app or use existing
5. Copy the **API Key** (Consumer Key)

### 3. Current Truck Configuration (US Standard Semi)

**Pre-configured for standard US 53' semi-trailer:**

```swift
// Line ~23 in NavigationViewController.swift
private var truckParameters = TruckParameters(
    weight: 36287,      // 80,000 lbs (US legal limit)
    axleWeight: 15422,  // 34,000 lbs per axle group
    length: 16.15,      // 53 ft trailer
    width: 2.44,        // 8 ft
    height: 4.11,       // 13'6" (standard semi height)
    commercialVehicle: true,
    loadType: nil       // Enable for hazmat
)
```

### 4. Enable Hazmat Mode (Tunnel Avoidance)

**To enable hazmat restrictions, uncomment line ~87:**

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    // ... setup code ...

    // Uncomment this line:
    enableHazmatMode()  // ← Enables tunnel avoidance + hazmat class
}
```

**Or configure manually:**

```swift
// Enable specific hazmat classes
enableHazmatMode(hazmatClasses: ["USHazmatClass1", "USHazmatClass3"])

// Enable toll avoidance
enableTollAvoidance()

// Enable ferry avoidance
enableFerryAvoidance()
```

### 5. Route Avoidance Options

Available avoidances (configured in `TruckParameters`):

```swift
var avoidTolls: Bool = false              // Avoid toll roads
var avoidMotorways: Bool = false          // Avoid highways
var avoidFerries: Bool = false            // Avoid ferries
var avoidUnpavedRoads: Bool = true        // Avoid unpaved (default ON)
var avoidTunnels: Bool = false            // Avoid tunnels (for hazmat)
var avoidBorderCrossings: Bool = false    // Avoid borders
```

### 6. Hazmat Classes Reference

Available US DOT hazmat classes:
- `USHazmatClass1` - Explosives
- `USHazmatClass2` - Gases (Flammable/Non-flammable)
- `USHazmatClass3` - Flammable liquids
- `USHazmatClass4` - Flammable solids
- `USHazmatClass5` - Oxidizers & Organic peroxides
- `USHazmatClass6` - Toxic materials & Infectious substances
- `USHazmatClass7` - Radioactive materials
- `USHazmatClass8` - Corrosives
- `USHazmatClass9` - Miscellaneous dangerous goods

**Example: Gasoline tanker (Class 3)**
```swift
enableHazmatMode(hazmatClasses: ["USHazmatClass3"])
```

## 🧪 Testing

### 1. Build and Run
```
⌘R in Xcode
```

### 2. Check Console Logs

Look for these success messages:
```
✅ Free-drive navigation active
🚛 Calculating TRUCK route from...
🚛 Truck params: 18000kg, 4.0m height
✅ Truck route calculated: XXXm, XXXs
🚛 Route respects truck restrictions!
✅ Truck route line drawn on map (orange)
```

### 3. Test Features

- **Search**: Type a destination → should show results
- **Route**: Tap "Set Test Destination" → Orange route appears
- **Restrictions**: Routes will avoid low bridges, weight restrictions, etc.

### 4. Compare Routes

Test the same destination with:
1. Google Maps (car route)
2. Your TruckNavPro (truck route)

Truck routes will be different - avoiding:
- Low bridges/tunnels
- Weight-restricted roads
- Width/height restrictions
- Non-commercial zones

## 🚨 Troubleshooting

### "TomTom API key not found"
- Check Info.plist has `TomTomAPIKey`
- Key must be valid from TomTom Developer Portal

### Route not calculating
- Check console for API errors
- Verify TomTom API key is active
- Check internet connection
- Try different destination

### Route looks same as car route
- Increase truck parameters (higher weight/height)
- Test in areas with known restrictions
- Check console for "Route respects truck restrictions!"

## 📝 Next Steps

### For Production:
1. Let users customize truck parameters in settings
2. Add turn-by-turn voice guidance (TomTom has detailed instructions API)
3. Save favorite truck parameters
4. Add multiple vehicle profiles
5. Offline route caching

### Want More Features?
- Real-time traffic for trucks
- Weigh station locations
- Rest area finder
- Fuel optimization
- Multiple waypoints

## 🎯 Current Status

**Ready to test!** Just add your TomTom API key and build.

Route will be shown in **orange** (truck routes) vs blue (car routes).
