-- ============================================================
-- 01_schema_and_load.sql
-- Supercapacitor electrode materials database
-- Builds the database, stages the cleaned CSV, creates the
-- normalized schema, and populates it.
--
-- Run in MySQL Workbench in two parts:
--   PART A  -> then import the CSV (instructions below)
--   PART B onwards -> after the import
-- ============================================================


-- ============================================================
-- PART A: DATABASE AND STAGING TABLE
-- ============================================================

-- Fresh, empty database. utf8mb4 handles subscripts and special
-- characters in material names (e.g. Fe₂O₃, °C) without errors.
CREATE DATABASE supercapacitor_materials
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Point every following query at the new database
USE supercapacitor_materials;

-- Landing table for the cleaned CSV. Every column is text, so
-- blank cells can't cause the import wizard to reject rows.
-- Types are converted during population (Part C), not import.
CREATE TABLE staging_raw (
    citation                  VARCHAR(500),
    year                      VARCHAR(20),
    material_name             VARCHAR(200),
    material_class            VARCHAR(50),
    material_class_detail     VARCHAR(300),
    synthesis_method          VARCHAR(500),
    synthesis_temp_K          VARCHAR(20),
    synthesis_temp_detail     VARCHAR(300),
    electrolyte               VARCHAR(200),
    measurement_type          VARCHAR(10),
    measurement_value         VARCHAR(20),
    measurement_unit          VARCHAR(20),
    measurement_detail        VARCHAR(300),
    specific_capacitance_F_g  VARCHAR(20),
    cycles_tested             VARCHAR(20),
    retention_pct             VARCHAR(20),
    energy_density_Wh_kg      VARCHAR(20),
    power_density_W_kg        VARCHAR(20),
    notes                     TEXT
);

-- ------------------------------------------------------------
-- STOP HERE AND IMPORT THE CSV
-- In the Navigator, refresh Schemas, right-click staging_raw
-- -> Table Data Import Wizard -> select
-- data/Materials_Extraction_cleaned.csv -> "Use existing table"
-- -> finish. Then run the check below; it should return 23.
-- ------------------------------------------------------------

SELECT COUNT(*) AS staged_rows FROM staging_raw;


-- ============================================================
-- PART B: TRACEABILITY ID AND NORMALIZED SCHEMA
-- ============================================================

-- Give each staging row a permanent ID, in CSV order.
-- Added after the import so the wizard doesn't need to map it.
ALTER TABLE staging_raw
    ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY FIRST;

-- One row per paper
CREATE TABLE sources (
    source_id  INT AUTO_INCREMENT PRIMARY KEY,
    citation   VARCHAR(500) NOT NULL UNIQUE,
    year       INT NOT NULL
);

-- One row per material tested (one per staging row)
CREATE TABLE materials (
    material_id      INT AUTO_INCREMENT PRIMARY KEY,
    staging_row_id   INT NOT NULL UNIQUE,   -- traceability back to the CSV row
    source_id        INT NOT NULL,
    material_name    VARCHAR(200) NOT NULL,
    material_class   VARCHAR(50) NOT NULL,
    class_detail     VARCHAR(300),
    FOREIGN KEY (source_id) REFERENCES sources(source_id),
    CONSTRAINT chk_material_class CHECK (material_class IN
        ('Carbon-based', 'Metal oxide', 'Conducting polymer', 'Hybrid/composite'))
);

-- How each material was made
CREATE TABLE synthesis_methods (
    synthesis_id           INT AUTO_INCREMENT PRIMARY KEY,
    material_id            INT NOT NULL,
    method_description     VARCHAR(500),
    synthesis_temp_K       DECIMAL(6,2),
    synthesis_temp_detail  VARCHAR(300),
    FOREIGN KEY (material_id) REFERENCES materials(material_id)
);

-- The electrochemical test setup
CREATE TABLE test_conditions (
    test_id             INT AUTO_INCREMENT PRIMARY KEY,
    material_id         INT NOT NULL,
    electrolyte         VARCHAR(200),
    measurement_type    VARCHAR(10),
    measurement_value   DECIMAL(10,4),
    measurement_unit    VARCHAR(20),
    measurement_detail  VARCHAR(300),
    FOREIGN KEY (material_id) REFERENCES materials(material_id),
    CONSTRAINT chk_measurement_type CHECK (measurement_type IN ('GCD', 'CV'))
);

-- Measured outcomes for each material + synthesis + test combination
CREATE TABLE performance_results (
    result_id                 INT AUTO_INCREMENT PRIMARY KEY,
    material_id               INT NOT NULL,
    synthesis_id              INT NOT NULL,
    test_id                   INT NOT NULL,
    specific_capacitance_F_g  DECIMAL(10,2),
    cycles_tested             INT,
    retention_pct             DECIMAL(5,2),
    energy_density_Wh_kg      DECIMAL(10,2),
    power_density_W_kg        DECIMAL(10,2),
    notes                     TEXT,
    FOREIGN KEY (material_id)  REFERENCES materials(material_id),
    FOREIGN KEY (synthesis_id) REFERENCES synthesis_methods(synthesis_id),
    FOREIGN KEY (test_id)      REFERENCES test_conditions(test_id)
);


-- ============================================================
-- PART C: POPULATE, in parent -> child order.
-- Pattern used for every numeric column:
--   NULLIF(TRIM(x), '')  -> strips spaces, turns blank into NULL
--   CAST(... AS type)    -> converts the text into a real number
-- ============================================================

-- 1. sources: GROUP BY collapses papers that report several
--    materials into one row each. MIN(year) guarantees a single
--    year per paper, so the UNIQUE constraint can't be violated.
INSERT INTO sources (citation, year)
SELECT TRIM(citation),
       MIN(CAST(NULLIF(TRIM(year), '') AS UNSIGNED))
FROM staging_raw
GROUP BY TRIM(citation);

-- 2. materials: one per staging row, linked to its paper
INSERT INTO materials (staging_row_id, source_id, material_name, material_class, class_detail)
SELECT sr.row_id,
       s.source_id,
       TRIM(sr.material_name),
       TRIM(sr.material_class),
       NULLIF(TRIM(sr.material_class_detail), '')
FROM staging_raw sr
JOIN sources s ON TRIM(sr.citation) = s.citation;

-- 3. synthesis_methods: matched through the row ID, so it's exact
INSERT INTO synthesis_methods (material_id, method_description, synthesis_temp_K, synthesis_temp_detail)
SELECT m.material_id,
       NULLIF(TRIM(sr.synthesis_method), ''),
       CAST(NULLIF(TRIM(sr.synthesis_temp_K), '') AS DECIMAL(6,2)),
       NULLIF(TRIM(sr.synthesis_temp_detail), '')
FROM staging_raw sr
JOIN materials m ON m.staging_row_id = sr.row_id;

-- 4. test_conditions
INSERT INTO test_conditions (material_id, electrolyte, measurement_type, measurement_value, measurement_unit, measurement_detail)
SELECT m.material_id,
       NULLIF(TRIM(sr.electrolyte), ''),
       NULLIF(TRIM(sr.measurement_type), ''),
       CAST(NULLIF(TRIM(sr.measurement_value), '') AS DECIMAL(10,4)),
       NULLIF(TRIM(sr.measurement_unit), ''),
       NULLIF(TRIM(sr.measurement_detail), '')
FROM staging_raw sr
JOIN materials m ON m.staging_row_id = sr.row_id;

-- 5. performance_results: picks up all three IDs.
--    REPLACE strips the hidden Windows line-ending (\r) that can
--    stick to the last CSV column (notes).
INSERT INTO performance_results (material_id, synthesis_id, test_id,
    specific_capacitance_F_g, cycles_tested, retention_pct,
    energy_density_Wh_kg, power_density_W_kg, notes)
SELECT m.material_id,
       sm.synthesis_id,
       tc.test_id,
       CAST(NULLIF(TRIM(sr.specific_capacitance_F_g), '') AS DECIMAL(10,2)),
       CAST(NULLIF(TRIM(sr.cycles_tested), '')            AS UNSIGNED),
       CAST(NULLIF(TRIM(sr.retention_pct), '')            AS DECIMAL(5,2)),
       CAST(NULLIF(TRIM(sr.energy_density_Wh_kg), '')     AS DECIMAL(10,2)),
       CAST(NULLIF(TRIM(sr.power_density_W_kg), '')       AS DECIMAL(10,2)),
       NULLIF(TRIM(REPLACE(sr.notes, '\r', '')), '')
FROM staging_raw sr
JOIN materials m          ON m.staging_row_id = sr.row_id
JOIN synthesis_methods sm ON sm.material_id   = m.material_id
JOIN test_conditions tc   ON tc.material_id   = m.material_id;


-- ============================================================
-- PART D: VERIFY
-- Expected: sources 14; every other table 23.
-- ============================================================
SELECT 'sources' AS table_name, COUNT(*) AS row_count FROM sources
UNION ALL SELECT 'materials',           COUNT(*) FROM materials
UNION ALL SELECT 'synthesis_methods',   COUNT(*) FROM synthesis_methods
UNION ALL SELECT 'test_conditions',     COUNT(*) FROM test_conditions
UNION ALL SELECT 'performance_results', COUNT(*) FROM performance_results;
