-- ============================================================
-- 02_categories_and_labels.sql
-- Run after 01_schema_and_load.sql.
-- Adds the analysis columns used by the Power BI dashboard:
--   method_category  -> six synthesis route categories
--   comparison_group -> tags the within-paper controlled comparisons
--   variant_label    -> short chart labels for those comparisons
-- ============================================================

USE supercapacitor_materials;

-- New columns start empty (NULL) in every row.
ALTER TABLE synthesis_methods
    ADD COLUMN method_category  VARCHAR(50),
    ADD COLUMN comparison_group VARCHAR(100),
    ADD COLUMN variant_label    VARCHAR(50);


-- ------------------------------------------------------------
-- 1. Synthesis route categories
-- Rule: categorize by the step that defines the material's
-- structure (e.g. electrospinning + carbonization -> carbonization).
-- ------------------------------------------------------------
UPDATE synthesis_methods SET method_category = 'Hydrothermal/solvothermal'   WHERE synthesis_id IN (18,19,20,21,22,23);
UPDATE synthesis_methods SET method_category = 'Carbonization & activation'  WHERE synthesis_id IN (4,5,6,7,8);
UPDATE synthesis_methods SET method_category = 'Electrochemical deposition'  WHERE synthesis_id IN (1,2,10,11);
UPDATE synthesis_methods SET method_category = 'Chemical polymerization'     WHERE synthesis_id IN (9,12,13);
UPDATE synthesis_methods SET method_category = 'Precipitation & calcination' WHERE synthesis_id IN (3,16,17);
UPDATE synthesis_methods SET method_category = 'Post-synthesis doping'       WHERE synthesis_id IN (14,15);


-- ------------------------------------------------------------
-- 2. Controlled comparisons: same paper, same electrolyte and
-- test method, only the synthesis changes. All other rows stay
-- NULL, meaning "not part of a comparison".
-- ------------------------------------------------------------
UPDATE synthesis_methods SET comparison_group = 'Coal pretreatment temperature'   WHERE synthesis_id IN (7,8);
UPDATE synthesis_methods SET comparison_group = 'Electropolymerization substrate' WHERE synthesis_id IN (10,11);
UPDATE synthesis_methods SET comparison_group = 'Fe2O3 morphology'                WHERE synthesis_id IN (21,22,23);


-- ------------------------------------------------------------
-- 3. Short labels for the comparison charts
-- ------------------------------------------------------------
UPDATE synthesis_methods SET variant_label = '520 °C char'       WHERE synthesis_id = 7;
UPDATE synthesis_methods SET variant_label = '1000 °C char'      WHERE synthesis_id = 8;
UPDATE synthesis_methods SET variant_label = 'Stainless steel'   WHERE synthesis_id = 10;
UPDATE synthesis_methods SET variant_label = 'Titanium'          WHERE synthesis_id = 11;
UPDATE synthesis_methods SET variant_label = '0D nanoparticles'  WHERE synthesis_id = 21;
UPDATE synthesis_methods SET variant_label = '1D nanorods'       WHERE synthesis_id = 22;
UPDATE synthesis_methods SET variant_label = '3D nanorod ovoids' WHERE synthesis_id = 23;


-- ============================================================
-- VERIFY
-- ============================================================

-- Expected: six categories with counts 6, 5, 4, 3, 3, 2 and no NULL row.
SELECT method_category, COUNT(*) AS n
FROM synthesis_methods
GROUP BY method_category;

-- Expected: seven rows; within each group the electrolyte and
-- measurement conditions should be identical.
SELECT s.comparison_group, s.variant_label,
       p.specific_capacitance_F_g, p.retention_pct, p.cycles_tested,
       t.measurement_type, t.measurement_value, t.measurement_unit, t.electrolyte
FROM performance_results p
JOIN synthesis_methods s ON p.synthesis_id = s.synthesis_id
JOIN test_conditions  t ON p.test_id      = t.test_id
WHERE s.comparison_group IS NOT NULL
ORDER BY s.comparison_group, s.synthesis_id;
