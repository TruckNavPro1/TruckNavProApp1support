-- TruckNavPro POI Database Setup
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard/project/tsjaqhetnsnhqgnfhikn/sql

-- ============================================================================
-- 1. ENABLE REQUIRED EXTENSIONS
-- ============================================================================

-- Enable PostGIS for location queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 2. CREATE POIS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS pois (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    phone TEXT,
    website TEXT,
    amenities TEXT[] DEFAULT '{}',
    brands TEXT[],
    rating DOUBLE PRECISION,
    review_count INTEGER DEFAULT 0,
    is_open_24_hours BOOLEAN DEFAULT FALSE,
    operating_hours JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Add geography column for spatial queries
    location GEOGRAPHY(POINT, 4326)
);

-- Generate location from lat/lng automatically
CREATE OR REPLACE FUNCTION update_poi_location()
RETURNS TRIGGER AS $$
BEGIN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER poi_location_trigger
    BEFORE INSERT OR UPDATE ON pois
    FOR EACH ROW
    EXECUTE FUNCTION update_poi_location();

-- Create spatial index for fast location queries
CREATE INDEX IF NOT EXISTS idx_pois_location ON pois USING GIST(location);

-- Create indexes for filtering
CREATE INDEX IF NOT EXISTS idx_pois_type ON pois(type);
CREATE INDEX IF NOT EXISTS idx_pois_state ON pois(state);

-- ============================================================================
-- 3. CREATE POI REVIEWS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS poi_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poi_id UUID NOT NULL REFERENCES pois(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_name TEXT,
    rating DOUBLE PRECISION NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    amenity_ratings JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_reviews_poi_id ON poi_reviews(poi_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON poi_reviews(user_id);

-- ============================================================================
-- 4. CREATE USER FAVORITE POIS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_favorite_pois (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    poi_id UUID NOT NULL REFERENCES pois(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Prevent duplicate favorites
    UNIQUE(user_id, poi_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON user_favorite_pois(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_poi_id ON user_favorite_pois(poi_id);

-- ============================================================================
-- 5. CREATE RPC FUNCTION: GET POIS NEAR LOCATION
-- ============================================================================

CREATE OR REPLACE FUNCTION get_pois_near_location(
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    radius_meters INT DEFAULT 50000,
    poi_types TEXT[] DEFAULT NULL,
    min_rating DOUBLE PRECISION DEFAULT NULL,
    required_amenities TEXT[] DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    type TEXT,
    name TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    phone TEXT,
    website TEXT,
    amenities TEXT[],
    brands TEXT[],
    rating DOUBLE PRECISION,
    review_count INTEGER,
    is_open_24_hours BOOLEAN,
    operating_hours JSONB,
    distance_meters DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    search_point GEOGRAPHY;
BEGIN
    -- Create search point
    search_point := ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography;

    RETURN QUERY
    SELECT
        p.id,
        p.type,
        p.name,
        p.address,
        p.city,
        p.state,
        p.zip_code,
        p.latitude,
        p.longitude,
        p.phone,
        p.website,
        p.amenities,
        p.brands,
        p.rating,
        p.review_count,
        p.is_open_24_hours,
        p.operating_hours,
        ST_Distance(p.location, search_point)::DOUBLE PRECISION as distance_meters,
        p.created_at,
        p.updated_at
    FROM pois p
    WHERE
        ST_DWithin(p.location, search_point, radius_meters)
        AND (poi_types IS NULL OR p.type = ANY(poi_types))
        AND (min_rating IS NULL OR p.rating >= min_rating)
        AND (required_amenities IS NULL OR p.amenities @> required_amenities)
    ORDER BY distance_meters
    LIMIT 100;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. CREATE RPC FUNCTION: GET POIS ALONG ROUTE
-- ============================================================================

CREATE OR REPLACE FUNCTION get_pois_along_route(
    route_coords JSONB,
    buffer_meters INT DEFAULT 5000,
    poi_types TEXT[] DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    type TEXT,
    name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    amenities TEXT[],
    rating DOUBLE PRECISION,
    distance_from_route DOUBLE PRECISION
) AS $$
DECLARE
    route_line GEOGRAPHY;
BEGIN
    -- Create line from route coordinates
    route_line := ST_MakeLine(
        ARRAY(
            SELECT ST_SetSRID(ST_MakePoint(
                (coord->>'lng')::DOUBLE PRECISION,
                (coord->>'lat')::DOUBLE PRECISION
            ), 4326)::geography
            FROM jsonb_array_elements(route_coords) AS coord
        )
    );

    RETURN QUERY
    SELECT
        p.id,
        p.type,
        p.name,
        p.latitude,
        p.longitude,
        p.amenities,
        p.rating,
        ST_Distance(p.location, route_line)::DOUBLE PRECISION as distance_from_route
    FROM pois p
    WHERE
        ST_DWithin(p.location, route_line, buffer_meters)
        AND (poi_types IS NULL OR p.type = ANY(poi_types))
    ORDER BY distance_from_route
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 7. INSERT SAMPLE DATA (Major US Truck Stops)
-- ============================================================================

-- Insert sample truck stops in major US cities
INSERT INTO pois (type, name, address, city, state, zip_code, latitude, longitude, phone, amenities, is_open_24_hours) VALUES
('truck_stop', 'Pilot Travel Center', '1234 Interstate Dr', 'Los Angeles', 'CA', '90001', 34.0522, -118.2437, '555-0100', ARRAY['diesel', 'showers', 'restrooms', 'wifi', 'restaurant', 'parking', 'scales'], true),
('truck_stop', 'Love''s Travel Stop', '5678 Highway Blvd', 'Phoenix', 'AZ', '85001', 33.4484, -112.0740, '555-0200', ARRAY['diesel', 'showers', 'restrooms', 'wifi', 'fast_food', 'parking', 'scales'], true),
('truck_stop', 'TA Truck Service', '9012 Freeway Ave', 'Houston', 'TX', '77001', 29.7604, -95.3698, '555-0300', ARRAY['diesel', 'showers', 'restrooms', 'wifi', 'restaurant', 'parking', 'repairs', 'scales'], true),
('truck_stop', 'Flying J Travel Plaza', '3456 Route 66', 'Chicago', 'IL', '60601', 41.8781, -87.6298, '555-0400', ARRAY['diesel', 'showers', 'restrooms', 'wifi', 'restaurant', 'parking', 'scales', 'laundry'], true),
('truck_stop', 'Petro Stopping Center', '7890 Turnpike Rd', 'Atlanta', 'GA', '30301', 33.7490, -84.3880, '555-0500', ARRAY['diesel', 'showers', 'restrooms', 'wifi', 'restaurant', 'parking', 'scales', 'tire_service'], true),
('rest_area', 'I-10 Westbound Rest Area', 'Mile Marker 245', 'El Paso', 'TX', '79901', 31.7619, -106.4850, NULL, ARRAY['restrooms', 'parking', 'wifi'], true),
('rest_area', 'I-40 Eastbound Rest Area', 'Mile Marker 178', 'Oklahoma City', 'OK', '73101', 35.4676, -97.5164, NULL, ARRAY['restrooms', 'parking'], true),
('weigh_station', 'California Agricultural Inspection Station', 'I-15 NB', 'Barstow', 'CA', '92311', 34.8958, -117.0228, '555-0600', ARRAY['scales'], false),
('weigh_station', 'Texas DPS Weigh Station', 'I-20 EB', 'Dallas', 'TX', '75201', 32.7767, -96.7970, '555-0700', ARRAY['scales'], false),
('fuel_station', 'Quick Fuel Truck Plaza', '2468 Industrial Way', 'Memphis', 'TN', '38101', 35.1495, -90.0490, '555-0800', ARRAY['diesel', 'parking'], true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 8. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on tables
ALTER TABLE pois ENABLE ROW LEVEL SECURITY;
ALTER TABLE poi_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorite_pois ENABLE ROW LEVEL SECURITY;

-- Allow anonymous users to read POIs
CREATE POLICY "Anyone can view POIs"
    ON pois FOR SELECT
    USING (true);

-- Allow anyone to read reviews
CREATE POLICY "Anyone can view reviews"
    ON poi_reviews FOR SELECT
    USING (true);

-- Allow authenticated users to write reviews
CREATE POLICY "Authenticated users can create reviews"
    ON poi_reviews FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- Allow users to manage their own favorites
CREATE POLICY "Users can view their own favorites"
    ON user_favorite_pois FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own favorites"
    ON user_favorite_pois FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites"
    ON user_favorite_pois FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- SETUP COMPLETE!
-- ============================================================================

-- Verify setup by counting POIs
SELECT
    type,
    COUNT(*) as count
FROM pois
GROUP BY type
ORDER BY count DESC;

-- Test the location query function
SELECT
    name,
    city,
    state,
    ROUND(distance_meters::NUMERIC / 1609.34, 1) as distance_miles
FROM get_pois_near_location(34.0522, -118.2437, 100000)
LIMIT 5;
