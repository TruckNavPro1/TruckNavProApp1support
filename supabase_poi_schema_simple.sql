-- Drop existing POI objects
DROP TRIGGER IF EXISTS update_rating_on_review_change ON public.poi_reviews;
DROP TRIGGER IF EXISTS update_poi_reviews_updated_at ON public.poi_reviews;
DROP TRIGGER IF EXISTS update_pois_updated_at ON public.pois;
DROP FUNCTION IF EXISTS update_poi_rating();
DROP FUNCTION IF EXISTS get_pois_along_route(JSONB, INTEGER, TEXT[]);
DROP FUNCTION IF EXISTS get_pois_near_location(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, TEXT[], DOUBLE PRECISION, TEXT[]);
DROP TABLE IF EXISTS public.user_favorite_pois;
DROP TABLE IF EXISTS public.poi_reviews;
DROP TABLE IF EXISTS public.pois;

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create pois table
CREATE TABLE public.pois (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN ('truck_stop', 'rest_area', 'weigh_station', 'truck_parking', 'fuel_station', 'service_center')),
    name TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography) STORED,
    phone TEXT,
    website TEXT,
    amenities TEXT[] DEFAULT '{}',
    brands TEXT[] DEFAULT '{}',
    rating DOUBLE PRECISION CHECK (rating >= 0 AND rating <= 5),
    review_count INTEGER DEFAULT 0,
    is_open_24_hours BOOLEAN DEFAULT false,
    operating_hours JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pois_location ON public.pois USING GIST (location);
CREATE INDEX idx_pois_type ON public.pois (type);
CREATE INDEX idx_pois_rating ON public.pois (rating) WHERE rating IS NOT NULL;
CREATE INDEX idx_pois_state ON public.pois (state);
CREATE INDEX idx_pois_brands ON public.pois USING GIN (brands);
CREATE INDEX idx_pois_amenities ON public.pois USING GIN (amenities);

-- Create poi_reviews table
CREATE TABLE public.poi_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poi_id UUID NOT NULL REFERENCES public.pois(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_name TEXT,
    rating DOUBLE PRECISION NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    amenity_ratings JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_poi_reviews_poi_id ON public.poi_reviews (poi_id);
CREATE INDEX idx_poi_reviews_user_id ON public.poi_reviews (user_id);
CREATE INDEX idx_poi_reviews_rating ON public.poi_reviews (rating);
CREATE INDEX idx_poi_reviews_created_at ON public.poi_reviews (created_at DESC);

-- Create user_favorite_pois table
CREATE TABLE public.user_favorite_pois (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    poi_id UUID NOT NULL REFERENCES public.pois(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, poi_id)
);

CREATE INDEX idx_user_favorite_pois_user_id ON public.user_favorite_pois (user_id);
CREATE INDEX idx_user_favorite_pois_poi_id ON public.user_favorite_pois (poi_id);

-- Create triggers (using existing update_updated_at_column function)
CREATE TRIGGER update_pois_updated_at
    BEFORE UPDATE ON public.pois
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_poi_reviews_updated_at
    BEFORE UPDATE ON public.poi_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create POI rating update function
CREATE OR REPLACE FUNCTION update_poi_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.pois
    SET
        rating = (SELECT AVG(rating) FROM public.poi_reviews WHERE poi_id = COALESCE(NEW.poi_id, OLD.poi_id)),
        review_count = (SELECT COUNT(*) FROM public.poi_reviews WHERE poi_id = COALESCE(NEW.poi_id, OLD.poi_id))
    WHERE id = COALESCE(NEW.poi_id, OLD.poi_id);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_rating_on_review_change
    AFTER INSERT OR UPDATE OR DELETE ON public.poi_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_poi_rating();

-- Create RPC function: get_pois_near_location
CREATE OR REPLACE FUNCTION get_pois_near_location(
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 50000,
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
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
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
        ST_Distance(p.location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) AS distance_meters,
        p.created_at,
        p.updated_at
    FROM public.pois p
    WHERE
        ST_DWithin(p.location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, radius_meters)
        AND (poi_types IS NULL OR p.type = ANY(poi_types))
        AND (min_rating IS NULL OR p.rating >= min_rating)
        AND (required_amenities IS NULL OR p.amenities @> required_amenities)
    ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create RPC function: get_pois_along_route
CREATE OR REPLACE FUNCTION get_pois_along_route(
    route_coords JSONB,
    buffer_meters INTEGER DEFAULT 5000,
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
    route_line := ST_MakeLine(
        ARRAY(
            SELECT ST_SetSRID(
                ST_MakePoint(
                    (coord->>'lng')::DOUBLE PRECISION,
                    (coord->>'lat')::DOUBLE PRECISION
                ), 4326
            )::geography
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
        ST_Distance(p.location, route_line) AS distance_from_route
    FROM public.pois p
    WHERE
        ST_DWithin(p.location, route_line, buffer_meters)
        AND (poi_types IS NULL OR p.type = ANY(poi_types))
    ORDER BY distance_from_route ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Enable Row Level Security
ALTER TABLE public.pois ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poi_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_favorite_pois ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "POIs are viewable by everyone" ON public.pois;
DROP POLICY IF EXISTS "Authenticated users can insert POIs" ON public.pois;
DROP POLICY IF EXISTS "Users can update their own POI submissions" ON public.pois;
DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.poi_reviews;
DROP POLICY IF EXISTS "Authenticated users can insert reviews" ON public.poi_reviews;
DROP POLICY IF EXISTS "Users can update their own reviews" ON public.poi_reviews;
DROP POLICY IF EXISTS "Users can delete their own reviews" ON public.poi_reviews;
DROP POLICY IF EXISTS "Users can view their own favorites" ON public.user_favorite_pois;
DROP POLICY IF EXISTS "Users can add their own favorites" ON public.user_favorite_pois;
DROP POLICY IF EXISTS "Users can remove their own favorites" ON public.user_favorite_pois;

-- Create RLS policies
CREATE POLICY "POIs are viewable by everyone"
    ON public.pois FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can insert POIs"
    ON public.pois FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Users can update their own POI submissions"
    ON public.pois FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "Reviews are viewable by everyone"
    ON public.poi_reviews FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can insert reviews"
    ON public.poi_reviews FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reviews"
    ON public.poi_reviews FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reviews"
    ON public.poi_reviews FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own favorites"
    ON public.user_favorite_pois FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can add their own favorites"
    ON public.user_favorite_pois FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove their own favorites"
    ON public.user_favorite_pois FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Insert sample data
INSERT INTO public.pois (type, name, address, city, state, zip_code, latitude, longitude, phone, amenities, brands, is_open_24_hours) VALUES
('truck_stop', 'Flying J Travel Center', '1234 Highway 40', 'Nashville', 'TN', '37211', 36.1627, -86.7816, '615-555-0100', ARRAY['diesel', 'showers', 'restaurant', 'wifi', 'parking', 'scales'], ARRAY['Flying J'], true),
('truck_stop', 'Love''s Travel Stop', '5678 Interstate Dr', 'Memphis', 'TN', '38118', 35.1495, -90.0490, '901-555-0200', ARRAY['diesel', 'showers', 'fast_food', 'wifi', 'parking'], ARRAY['Love''s'], true),
('rest_area', 'I-40 Rest Area Eastbound', 'Interstate 40 Mile 201', 'Jackson', 'TN', '38305', 35.6145, -88.8139, NULL, ARRAY['restrooms', 'parking', 'wifi'], NULL, true),
('weigh_station', 'Tennessee DOT Weigh Station', 'I-40 Eastbound', 'Lebanon', 'TN', '37087', 36.2081, -86.2911, '615-555-0300', ARRAY['scales'], NULL, true),
('fuel_station', 'TA Truck Service', '9999 Truck Plaza Rd', 'Knoxville', 'TN', '37922', 35.9606, -83.9207, '865-555-0400', ARRAY['diesel', 'def', 'repairs', 'tire_service', 'parking'], ARRAY['TravelCenters of America'], true);

SELECT 'POI database schema created successfully!' AS status;
