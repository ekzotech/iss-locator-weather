-- 1 up
CREATE TABLE observations (
  observed_at INTEGER PRIMARY KEY,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL
);

-- 1 down
DROP TABLE observations;

-- 2 up
CREATE TRIGGER observations_coordinates_insert
BEFORE INSERT ON observations
WHEN NEW.latitude NOT BETWEEN -90 AND 90 OR NEW.longitude NOT BETWEEN -180 AND 180
BEGIN
  SELECT RAISE(ABORT, 'Observation coordinates out of range');
END;

CREATE TRIGGER observations_coordinates_update
BEFORE UPDATE OF latitude, longitude ON observations
WHEN NEW.latitude NOT BETWEEN -90 AND 90 OR NEW.longitude NOT BETWEEN -180 AND 180
BEGIN
  SELECT RAISE(ABORT, 'Observation coordinates out of range');
END;

-- 2 down
DROP TRIGGER observations_coordinates_update;
DROP TRIGGER observations_coordinates_insert;

-- 3 up
ALTER TABLE observations ADD COLUMN weather_status TEXT NOT NULL DEFAULT 'unavailable'
  CHECK (weather_status IN ('available', 'water', 'unavailable'));

-- 3 down
ALTER TABLE observations DROP COLUMN weather_status;

-- 4 up
ALTER TABLE observations ADD COLUMN temperature_c REAL;
ALTER TABLE observations ADD COLUMN cloud_cover INTEGER CHECK (cloud_cover BETWEEN 0 AND 100);
ALTER TABLE observations ADD COLUMN weather_code INTEGER;
ALTER TABLE observations ADD COLUMN weather_at INTEGER;

-- 4 down
ALTER TABLE observations DROP COLUMN weather_at;
ALTER TABLE observations DROP COLUMN weather_code;
ALTER TABLE observations DROP COLUMN cloud_cover;
ALTER TABLE observations DROP COLUMN temperature_c;
