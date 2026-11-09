-- 1 up
CREATE TABLE observations (
  observed_at INTEGER PRIMARY KEY,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL
);

-- 1 down
DROP TABLE observations;
