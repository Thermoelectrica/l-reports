# SQL Queries Documentation

## data.sql

**Purpose:** Retrieves inspection data with defects and performs criticality calculations based on temperature readings, sticker values, and load factors. Used for the thermal control protocol report.

**Used for:** Thermal control protocol report — lists all defects found during inspections with calculated criticality levels.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:plant_name` | string | Yes | Plant/facility name |
| `:period_start` | date | Yes | Start of the reporting period |
| `:period_end` | date | Yes | End of the reporting period |
| `:include_developing` | boolean | No | Include developing defects in output (default: false) |

### Query Logic

The query uses five CTEs to aggregate, adjust, and calculate defect criticality:

#### `grouped_images` CTE — Image Aggregation
- Groups image IDs by `inspection_step_id` and `image_type`
- Concatenates image IDs with `.jpg` extension into an array
- Excludes images with `CCD` in the original filename
- Separates images into VISUAL and THERMAL types

#### `base_table` CTE — Main Data Assembly
- Joins inspection data with defect, equipment, and sticker information
- Concatenates facility and equipment paths for display (`full_equipment_name`)
- Assembles visual and thermal image arrays from `grouped_images`
- Calculates load factor: `measured_current / nominal_current`
- Calculates temperature excess: `t_observed - t_environment`
- Determines equipment type: `MOTOR` or `PANEL` based on equipment name

#### `adjusted_temperatures` CTE — Load Factor Classification & Temperature Normalization
- Extracts the first numeric value from `t_sticker` field (e.g., `100` from `>100` or `100-120`)
- Classifies load factor into ranges:
  - `LOW` — load < 0.3
  - `MEDIUM` — 0.3 ≤ load < 0.6
  - `HIGH` — 0.6 ≤ load ≤ 1.0
  - `OVERLOAD` — load > 1.0 or unknown currents
- Normalizes temperature excess to rated load:
  - `t_observed_excess_100` — normalized to 100% load: `∆T / load²`
  - `t_observed_excess_50` — normalized to 50% load (for MEDIUM with similar unit): `(∆T_similar) / load² / 4`
  - `t_observed_excess_medium_fallback` — fallback for MEDIUM without similar unit: `∆T / 0.6²`

#### `criticality_calc` CTE — Criticality Calculation
Calculates two criticality scores:

**Sticker-based (`criticality_sticker_numeric`):**
- `2` (EMERGENCY) — sticker temperature ≥ maximum allowed
- `3` (DEVELOPING) — sticker within limits

**Load-based (`criticality_load_numeric`):**
- **LOW load:** excess > 10°C → `1` (CRITICAL), otherwise → `3` (DEVELOPING)
- **MEDIUM load with similar unit:** normalized excess ≥ 30 → `2` (EMERGENCY), < 30 → `3` (DEVELOPING)
- **MEDIUM load without similar unit:** fallback excess > 0 → `1` (CRITICAL), otherwise → `3` (DEVELOPING)
- **HIGH load:** normalized excess - limit > 30 → `1` (CRITICAL), 0–30 → `2` (EMERGENCY), < 0 → `3` (DEVELOPING)
- **OVERLOAD:** current excess - limit > 30 → `1` (CRITICAL), 0–30 → `2` (EMERGENCY), < 0 → `3` (DEVELOPING)

Also calculates `t_sticker_excess` and `t_thermal_excess` (excess over allowed threshold).

#### `final_criticality` CTE — Final Criticality Determination
- Combines sticker and load criticality using `LEAST()` (most critical wins)
- Combines temperature excess using `GREATEST()` (highest excess wins)
- Maps numeric criticality to string: `1` → CRITICAL, `2` → EMERGENCY, `3` → DEVELOPING

#### Final SELECT
- Filters by criticality level based on `:include_developing` parameter
- Ordered by criticality, equipment type, equipment name, defect type, and unit name

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `full_equipment_name` | text | Facility + equipment path concatenated with ` > ` |
| `defect_type_name` | text | Full defect type name |
| `unit_name` | text | Unit name |
| `visual_image_ids` | text[] | Array of visual image filenames |
| `thermal_image_ids` | text[] | Array of thermal image filenames |
| `is_sticker_present` | boolean | Whether thermo-indicator sticker is present |
| `sticker_name` | text | Sticker type name |
| `t_sticker` | text | Sticker temperature reading (raw string) |
| `is_test_ready` | boolean | Testable or not |
| `t_environment` | numeric | Ambient temperature |
| `t_similar_unit` | numeric | Similar unit temperature |
| `t_observed` | numeric | Temperature registered by thermal camera |
| `t_max` | numeric | Maximum allowed temperature for defect type |
| `t_excess` | numeric | Maximum allowed temperature excess over ambient |
| `measured_current` | numeric | Measured current |
| `nominal_current` | numeric | Nominal current |
| `load_factor` | numeric | Load factor (`measured_current / nominal_current`) |
| `t_observed_excess` | numeric | Temperature excess over ambient (calculated) |
| `equipment_type_name` | text | Equipment type name |
| `is_panel` | text | `MOTOR` or `PANEL` based on equipment type |
| `full_name` | text | Inspector name |
| `t_sticker_min` | numeric | Parsed minimum sticker temperature |
| `load_factor_range` | text | Load range: `LOW`, `MEDIUM`, `HIGH`, or `OVERLOAD` |
| `t_observed_excess_100` | numeric | Temperature excess normalized to 100% load |
| `t_observed_excess_50` | numeric | Temperature excess normalized to 50% load (for similar unit comparison) |
| `t_observed_excess_medium_fallback` | numeric | Fallback normalized excess for MEDIUM without similar unit |
| `criticality_sticker_numeric` | int | Sticker-based criticality: 1=CRITICAL, 2=EMERGENCY, 3=DEVELOPING |
| `criticality_load_numeric` | int | Load-based criticality: 1=CRITICAL, 2=EMERGENCY, 3=DEVELOPING |
| `t_sticker_excess` | numeric | Sticker temperature excess over maximum |
| `t_thermal_excess` | numeric | Thermal camera excess over allowed threshold |
| `t_over_max_excess` | numeric | Maximum excess from sticker or thermal camera |
| `criticality_numeric` | int | Final criticality (most critical of sticker + load) |
| `criticality` | text | Final criticality string: `CRITICAL`, `EMERGENCY`, or `DEVELOPING` |
| `criticality_sort` | int | Sort key for criticality (same as criticality_numeric) |

### Tables Referenced

- `lesiv.inspection` — Inspection records
- `lesiv.inspection_step` — Inspection step records (defect data)
- `lesiv.equipment_defect` — Equipment defect records
- `lesiv.equipment_detailed_view` — Equipment detailed view (hierarchy info)
- `lesiv.defect_type` — Defect type definitions
- `lesiv.sticker_type` — Sticker type definitions
- `lesiv.inspector` — Inspector information
- `lesiv.image` — Image records
- `lesiv.inspection_image_link` — Link between images and inspection steps

---

## plant_list.sql

**Purpose:** Returns a list of all available plants for the `plant_name` parameter dropdown.

**Used for:** Enum query for the `plant_name` parameter in `metadata.yaml`.

### Parameters

None.

### Query Logic

- Selects all non-deleted plants from `lesiv.plant`
- Ordered alphabetically by name

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `name` | text | Plant name |

### Tables Referenced

- `lesiv.plant` — Plant master data

---

## inspection_dates.sql

**Purpose:** Returns distinct inspection dates for a given plant and period.

**Used for:** Displaying available inspection dates in the protocol report.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:plant_name` | string | Yes | Plant name |
| `:period_start` | date | Yes | Start of the reporting period |
| `:period_end` | date | Yes | End of the reporting period |

### Query Logic

- Selects distinct dates from `inspection.started_at`
- Joins with `equipment_detailed_view` to filter by plant
- Filters by date range
- Ordered by date ascending

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `inspection_date` | date | Distinct inspection date |

### Tables Referenced

- `lesiv.inspection` — Inspection records
- `lesiv.equipment_detailed_view` — Equipment detailed view

---

## inspection_summary.sql

**Purpose:** Returns summary statistics for inspected equipment — total control points and stickers per facility/folder.

**Used for:** Protocol header — shows total equipment and sticker counts for the reporting period.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:plant_name` | string | Yes | Plant name |
| `:period_start` | date | Yes | Start of the reporting period |
| `:period_end` | date | Yes | End of the reporting period |

### Query Logic

- Joins inspections with `equipment_detailed_view`
- Filters only leaf equipment (`is_container = false`)
- Aggregates total control points and sticker counts per facility/folder
- Formats folder name by replacing equipment path separators (` > ` → ` -`)
- Ordered by facility and folder name

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `facility_name` | text | Facility name |
| `full_folder_name` | text | Formatted folder name (equipment path with separators replaced) |
| `total_point_count` | bigint | Total number of control points |
| `total_sticker_count` | bigint | Total number of stickers |

### Tables Referenced

- `lesiv.inspection` — Inspection records
- `lesiv.equipment_detailed_view` — Equipment detailed view (hierarchy info)
