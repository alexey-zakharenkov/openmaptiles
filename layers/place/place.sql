CREATE TABLE IF NOT EXISTS osm_important_place_point AS (
    SELECT osm.geometry, osm.osm_id, osm.name, osm.name_en, osm.place, ne.scalerank, COALESCE(osm.population, ne.pop_min) AS population
    FROM ne_10m_populated_places AS ne, osm_place_point AS osm
    WHERE
    (
        ne.name ILIKE osm.name OR
        ne.name ILIKE osm.name_en OR
        ne.namealt ILIKE osm.name OR
        ne.namealt ILIKE osm.name_en OR
        ne.meganame ILIKE osm.name OR
        ne.meganame ILIKE osm.name_en OR
        ne.gn_ascii ILIKE osm.name OR
        ne.gn_ascii ILIKE osm.name_en OR
        ne.nameascii ILIKE osm.name OR
        ne.nameascii ILIKE osm.name_en
    )
    AND (osm.place = 'city' OR osm.place= 'town' OR osm.place = 'village')
    AND ST_DWithin(ne.geom, osm.geometry, 50000)
);

CREATE INDEX IF NOT EXISTS osm_important_place_point_geometry_idx ON osm_important_place_point USING gist(geometry);
CLUSTER osm_important_place_point USING osm_important_place_point_geometry_idx;

CREATE OR REPLACE VIEW place_z2 AS (
    SELECT geometry, name, place, scalerank, population
    FROM osm_important_place_point
    WHERE scalerank <= 0
);

CREATE OR REPLACE VIEW place_z3 AS (
    SELECT geometry, name, place, scalerank, population
    FROM osm_important_place_point
    WHERE scalerank <= 2
);

CREATE OR REPLACE VIEW place_z4 AS (
    SELECT geometry, name, place, scalerank, population
    FROM osm_important_place_point
    WHERE scalerank <= 5
);

CREATE OR REPLACE VIEW place_z5 AS (
    SELECT geometry, name, place, scalerank, population
    FROM osm_important_place_point
    WHERE scalerank <= 6
);

CREATE OR REPLACE VIEW place_z6 AS (
    SELECT geometry, name, place, scalerank, population
    FROM osm_important_place_point
    WHERE scalerank <= 7
);

CREATE OR REPLACE VIEW place_z7 AS (
    SELECT geometry, name, place, scalerank, population
    FROM osm_important_place_point
);

CREATE OR REPLACE VIEW place_z8 AS (
    SELECT geometry, name, place, NULL::integer AS scalerank, population FROM osm_place_point
    WHERE place IN ('city', 'town')
);

CREATE OR REPLACE VIEW place_z10 AS (
    SELECT geometry, name, place, NULL::integer AS scalerank, population FROM osm_place_point
    WHERE place IN ('city', 'town', 'village') OR place='subregion'
);

CREATE OR REPLACE VIEW place_z11 AS (
    SELECT geometry, name, place, NULL::integer AS scalerank, population FROM osm_place_point
);

CREATE OR REPLACE VIEW place_z13 AS (
    SELECT geometry, name, place, NULL::integer AS scalerank, population FROM osm_place_point
);

CREATE OR REPLACE FUNCTION layer_place(bbox geometry, zoom_level int, pixel_width numeric)
RETURNS TABLE(geometry geometry, name text, place text, scalerank int) AS $$
    SELECT geometry, name, place, scalerank FROM (
        SELECT geometry, name, place, scalerank,
        row_number() OVER (
            PARTITION BY LabelGrid(geometry, 150 * pixel_width)
            ORDER BY scalerank ASC NULLS LAST,
            population DESC NULLS LAST,
            length(name) DESC
        ) AS gridrank
        FROM (
            SELECT * FROM place_z2
            WHERE zoom_level = 2
            UNION ALL
            SELECT * FROM place_z3
            WHERE zoom_level = 3
            UNION ALL
            SELECT * FROM place_z4
            WHERE zoom_level = 4
            UNION ALL
            SELECT * FROM place_z5
            WHERE zoom_level = 5
            UNION ALL
            SELECT * FROM place_z6
            WHERE zoom_level = 6
            UNION ALL
            SELECT * FROM place_z7
            WHERE zoom_level = 7
            UNION ALL
            SELECT * FROM place_z8
            WHERE zoom_level BETWEEN 8 AND 9
            UNION ALL
            SELECT * FROM place_z10
            WHERE zoom_level = 10
            UNION ALL
            SELECT * FROM place_z11
            WHERE zoom_level BETWEEN 11 AND 12
            UNION ALL
            SELECT * FROM place_z13
            WHERE zoom_level >= 13
        ) AS zoom_levels
        WHERE geometry && bbox
    ) AS ranked_places
    WHERE
        zoom_level <= 7 OR
        (zoom_level = 8 AND gridrank <= 4) OR
        (zoom_level = 9 AND gridrank <= 9) OR
        (zoom_level = 10 AND gridrank <= 9) OR
        (zoom_level = 11 AND gridrank <= 9) OR
        (zoom_level = 12 AND gridrank <= 9) OR
        zoom_level >= 13;
$$ LANGUAGE SQL IMMUTABLE;