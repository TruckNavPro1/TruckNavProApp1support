# POI Database Setup Instructions

## Step 1: Run SQL Setup in Supabase

1. Open your Supabase dashboard:
   - Go to: https://supabase.com/dashboard/project/tsjaqhetnsnhqgnfhikn/sql

2. Click "SQL Editor" in the left sidebar

3. Click "+ New query"

4. Copy ALL contents from `SUPABASE_POI_SETUP.sql`

5. Paste into the SQL editor

6. Click "Run" button

7. You should see output showing:
   ```
   type          | count
   --------------|------
   truck_stop    | 5
   rest_area     | 2
   weigh_station | 2
   fuel_station  | 1
   ```

## Step 2: Verify Database is Working

In the SQL Editor, run this test query:

```sql
SELECT
    name,
    city,
    state,
    ROUND(distance_meters::NUMERIC / 1609.34, 1) as distance_miles
FROM get_pois_near_location(34.0522, -118.2437, 100000)
LIMIT 5;
```

You should see 5 truck stops near Los Angeles.

## Step 3: Import More POI Data (Optional but Recommended)

The setup only includes 10 sample POIs. To add thousands of real truck stops:

### Option A: Use Built-in Import Tool (Easier)

1. Build and run the app in Xcode
2. Open Settings
3. *(Need to add button to access POIImportViewController)*
4. Select "Import Major US Routes"
5. Wait 10-15 minutes for import to complete

### Option B: Manual Import from OpenStreetMap

Run the import script I'll create for you in the next step.

## Step 4: Test POIs in App

1. Build and run app in Xcode
2. Open the app
3. Zoom into Los Angeles area
4. You should see **orange truck stop markers** on the map
5. Tap a marker to see POI details (name, amenities, phone, etc.)

## Troubleshooting

### If POIs don't appear on map:

1. Check Xcode console for errors:
   ```
   ✅ POI manager initialized
   📍 Fetching POIs from Supabase near X, Y
   ✅ Fetched 5 POIs from Supabase
   📍 Displayed 5 POI markers on map
   ```

2. If you see errors like "Failed to fetch POIs", check:
   - SQL was run successfully in Supabase
   - Tables exist: Go to Table Editor in Supabase
   - RLS policies are correct (should allow anonymous reads)

3. If markers still don't appear:
   - Make sure you're zoomed into an area with POIs
   - Sample data is only in major US cities
   - Need to import more data via OSM

### If import fails:

- Check internet connection
- OpenStreetMap API may be rate-limiting (wait 5 minutes)
- Supabase database may have hit free tier limits

## What You Get

Once working, the app will show:

- **Truck Stops** (orange markers)
  - Name, address, phone
  - Amenities: showers, WiFi, scales, restaurant, etc.
  - 24/7 indicator
  - Star to favorite
  - Tap for directions

- **Rest Areas** (teal markers)
  - Location, facilities
  - Interstate info

- **Weigh Stations** (yellow markers)
  - Open/closed status
  - Scales availability

- **Fuel Stations** (green markers)
  - Diesel availability
  - Truck lanes

## Database Size Estimates

- **Sample data**: 10 POIs
- **Single state import**: 200-500 POIs
- **Major routes import**: 3,000-5,000 POIs
- **Full US import**: 15,000-20,000 POIs

Supabase free tier: 500 MB database (plenty for POIs)

## Next Steps

After POIs are working:
1. Add button in Settings to access POI import tool
2. Import more data for regions you drive
3. Consider adding user-submitted POIs
4. Add reviews/ratings functionality
