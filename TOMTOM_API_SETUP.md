# TomTom API Key Setup Guide

## 🔑 Why You Need a TomTom API Key

Your TruckNav Pro app uses TomTom services for:
- **Search** - Find truck stops, rest areas, fuel stations
- **Traffic** - Real-time traffic conditions and incidents
- **Routing** - Truck-optimized routing with restrictions
- **Hazard Monitoring** - Bridge heights, weight limits

## 🆓 Free Tier Includes:
- **2,500 requests/day** (plenty for development)
- All search, traffic, and routing APIs
- No credit card required for trial

---

## 📝 Step-by-Step Setup

### 1. Create TomTom Developer Account

1. Go to https://developer.tomtom.com/
2. Click **"Get Started for Free"** or **"Sign Up"**
3. Fill in your details:
   - Email address
   - Password
   - Name
4. Verify your email address

### 2. Create an App/Project

1. Log into https://developer.tomtom.com/
2. Go to **"Dashboard"** → **"My Apps"**
3. Click **"Create a New App"**
4. Fill in details:
   - **App Name**: TruckNav Pro
   - **Description**: Truck navigation app
   - **Platform**: iOS
5. Click **"Create App"**

### 3. Get Your API Key

1. In your app dashboard, you'll see your **Consumer API Key**
2. It looks like: `Nq78WMNfPT4Xvm8jV7KiYGp6nb55VDkO`
3. Copy this key (you'll need it in the next step)

### 4. Add API Key to Xcode Project

#### Option A: Using Xcode GUI

1. Open `TrucknavPro.xcodeproj` in Xcode
2. In the Project Navigator, click on `TrucknavPro` (blue project icon)
3. Select the `TrucknavPro` target
4. Go to the **"Info"** tab
5. Find the **"Custom iOS Target Properties"** section
6. Find or add `TomTomAPIKey` row:
   - Click **"+"** to add a new row
   - **Key**: `TomTomAPIKey`
   - **Type**: String
   - **Value**: Paste your API key
7. Save (⌘+S)

#### Option B: Edit Info.plist Directly

1. Open `TrucknavPro/Info.plist` in a text editor
2. Add this before the closing `</dict>` tag:

```xml
<key>TomTomAPIKey</key>
<string>YOUR_API_KEY_HERE</string>
```

Replace `YOUR_API_KEY_HERE` with your actual API key.

3. Save the file

### 5. Verify Setup

1. **Build and run** the app
2. **Check console output** for:
   ```
   🔑 Found TomTom API key: Nq78WMNfP...
   ✅ TomTom Services initialized successfully:
      - Routing: ✓
      - Traffic: ✓
      - Search: ✓
      - Hazard Monitoring: ✓
   ```

3. **Test search**:
   - Tap the search bar
   - Type "truck stop" or tap a category button
   - Should return results

---

## 🧪 Testing Your API Key

### Test Manually via cURL

```bash
# Replace YOUR_KEY with your actual API key
curl "https://api.tomtom.com/search/2/search/pizza.json?key=YOUR_KEY&lat=37.7749&lon=-122.4194&limit=5"
```

**Expected response**: JSON with search results

**If you see `HTTP 403`**: Invalid API key
**If you see `HTTP 429`**: Rate limit exceeded (wait a moment)

---

## 🔧 Troubleshooting

### "Search Unavailable" Alert

**Problem**: App shows "TomTom Search service is not configured"

**Solution**:
1. Check that `TomTomAPIKey` exists in Info.plist
2. Verify key is not empty
3. Clean build folder (⌘+Shift+K)
4. Rebuild project (⌘+B)

### "Invalid API Key" Error (403)

**Problem**: Search fails with 403 error

**Causes**:
- API key is incorrect or expired
- Key was disabled in TomTom dashboard
- Key hasn't activated yet (wait 5 minutes after creation)

**Solution**:
1. Verify key in TomTom dashboard: https://developer.tomtom.com/user/me/apps
2. Try generating a new key
3. Update Info.plist with new key
4. Clean and rebuild

### "Rate Limit Exceeded" Error (429)

**Problem**: Too many API requests

**Solution**:
- Free tier: 2,500 requests/day
- Wait for limit to reset (midnight UTC)
- Check dashboard for usage: https://developer.tomtom.com/user/me/apps
- Consider upgrading plan if needed

### No Console Output

**Problem**: Don't see initialization logs

**Solution**:
1. Make sure you're viewing the Xcode console (⌘+Shift+Y)
2. Try filtering for "TomTom" in console search
3. Check that NavigationViewController's viewDidLoad is being called

### Search Returns No Results

**Problem**: Search succeeds but finds nothing

**Reasons**:
- Your location might be in a remote area
- Category search has limited coverage
- Try generic search (e.g., "restaurant" instead of category)

**Solution**:
- Test in a populated area
- Try broader search terms
- Increase search radius (already 80km for categories)

---

## 📊 API Usage Limits

### Free Tier Limits

| API | Daily Limit | Notes |
|-----|-------------|-------|
| Search | 2,500 | Shared across all search types |
| Traffic Flow | 2,500 | Real-time traffic data |
| Traffic Incidents | 2,500 | Accident/closure data |
| Routing | 2,500 | Route calculations |
| **Total** | **2,500** | **Combined across all APIs** |

### What Counts as a Request?

- ✅ Each search query = 1 request
- ✅ Each traffic update = 1 request
- ✅ Each route calculation = 1 request
- ❌ Displaying results = 0 requests
- ❌ Selecting from results = 0 requests

### Optimizing Usage

**Current app optimizations:**
- Traffic widget: Updates every 30 seconds (≈2,880/day max)
- Search: Only on user action (not automatic)
- Caching: POI results cached for 1 hour
- Batch requests where possible

**For production:**
- Increase traffic update interval to 60s
- Cache search results longer
- Use POI database for common locations
- Consider paid tier for high traffic

---

## 🚀 Production Checklist

Before submitting to App Store:

- [ ] API key is configured in Info.plist
- [ ] Key is valid and active
- [ ] Tested search functionality
- [ ] Tested traffic widget
- [ ] Tested route calculation
- [ ] Monitored API usage for 1 week
- [ ] Ensured usage stays under limits
- [ ] Added error handling for rate limits
- [ ] Considered paid tier if needed

---

## 💰 Upgrading to Paid Tier

If you exceed free tier limits:

1. Go to https://developer.tomtom.com/pricing
2. Choose a plan:
   - **Starter**: 100,000 requests/month
   - **Growth**: 1,000,000 requests/month
   - **Premium**: Custom limits
3. Add payment method in dashboard
4. No code changes needed - same API key works

---

## 🔗 Useful Links

- **TomTom Developer Portal**: https://developer.tomtom.com/
- **Dashboard (API Keys)**: https://developer.tomtom.com/user/me/apps
- **Search API Docs**: https://developer.tomtom.com/search-api/documentation
- **Traffic API Docs**: https://developer.tomtom.com/traffic-api/documentation
- **Pricing**: https://developer.tomtom.com/pricing
- **Support**: https://developer.tomtom.com/support

---

## 📱 Alternative: Use Mapbox Search

If you don't want to use TomTom, the app can fall back to Mapbox Search:

1. Remove or leave TomTom API key blank
2. App will show "Search Unavailable" initially
3. Future update can add Mapbox Search fallback
4. Mapbox offers 100,000 free requests/month

---

## ✅ Quick Reference

**Get API Key**: https://developer.tomtom.com/
**Add to Project**: Info.plist → `TomTomAPIKey`
**Test Command**:
```bash
curl "https://api.tomtom.com/search/2/search/test.json?key=YOUR_KEY&lat=0&lon=0"
```

**Expected Console Output**:
```
🔑 Found TomTom API key: Nq78WMNfP...
✅ TomTom Services initialized successfully
```

**That's it! Happy searching! 🚛**
