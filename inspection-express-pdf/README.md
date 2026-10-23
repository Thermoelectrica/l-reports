# SQL Queries Documentation

## data.sql

**Purpose:** Retrieves inspection data with defects for a single-day period, including equipment inspection history and work log information. Used for the daily express protocol report.

**Used for:** Express protocol report — lists all defects found during inspections on a specific date.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:plant_name` | string | Yes | Plant/facility name |
| `:facility_name` | string | Yes | Equipment facility name (use `-= ВСЕ =-` for all) |
| `:equipment_path` | string | Yes | Equipment path/folder (use `-= ВСЕ =-` for all) |
| `:period_start` | date | Yes | Date of inspection (single day) |
| `:period_end` | date | Yes | End of the reporting period (hidden parameter) |

### Query Logic

The query uses five CTEs to aggregate and enrich data:

#### `grouped_images` CTE — Image Aggregation
- Groups image IDs by `inspection_step_id` and `image_type`
- Concatenates image IDs with `.jpg` extension into an array
- Excludes images with `CCD` in the original filename
- Separates images into VISUAL and THERMAL types

#### `insp_history` CTE — Inspection History
- Retrieves historical inspection data for each equipment (before the current period)
- Collects arrays of unit names, temperature excess, detection dates, sticker readings, observed temperatures, and ambient temperatures
- Ordered by `started_at DESC`
- Filters by plant and date range (`2026-01-01` to `period_start`)

#### `work_log_data` CTE — Work Log Inspectors
- Aggregates minor inspector names and positions from work log records
- Links inspectors to work log entries via `work_log_inspector`
- Groups by work log ID

#### `base_table` CTE — Main Data Assembly
- Joins inspection data with defect, equipment, and sticker information
- Concatenates facility and equipment paths for display (`full_equipment_name`)
- Assembles visual and thermal image arrays from `grouped_images`
- Adjusts zero temperatures to 1 (to avoid division by zero)
- Calculates load factor: `measured_current / nominal_current`
- Calculates temperature excess: `t_observed - t_environment`
- Determines equipment type: `MOTOR` or `PANEL` based on equipment name
- Includes defect status and resolution dates
- Joins work log data to associate minor inspectors with the inspection
- Includes inspection history arrays from `insp_history`

#### `adjusted_temperatures` CTE — Sticker Temperature Parsing
- Extracts the first numeric value from `t_sticker` field (e.g., `100` from `>100` or `100-120`)
- Uses regex substring to find digits

#### `criticality_calc` CTE — Criticality Calculation
- Calculates temperature excess based on sticker reading: `t_sticker_min - t_max`
- Returns 0 if sticker temperature does not exceed maximum

#### Final SELECT
- Returns all columns from `criticality_calc`
- Ordered by equipment name, defect type, and unit name

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `full_equipment_name` | text | Facility + equipment path concatenated with ` > ` |
| `defect_type_name` | text | Full defect type name |
| `defect_type_short_name` | text | Short defect type name |
| `unit_name` | text | Unit name |
| `visual_image_ids` | text[] | Array of visual image filenames |
| `thermal_image_ids` | text[] | Array of thermal image filenames |
| `is_sticker_present` | boolean | Whether thermo-indicator sticker is present |
| `sticker_name` | text | Sticker type name |
| `t_sticker` | text | Sticker temperature reading (raw string) |
| `is_test_ready` | boolean | Testable or not |
| `t_environment` | numeric | Ambient temperature (adjusted: 0 → 1) |
| `t_similar_unit` | numeric | Similar unit temperature (adjusted: 0 → 1) |
| `t_observed` | numeric | Temperature registered by thermal camera |
| `is_attention_required` | boolean | Whether attention is required |
| `is_resolved` | boolean | Whether defect is resolved |
| `t_max` | numeric | Maximum allowed temperature for defect type |
| `t_excess` | numeric | Maximum allowed temperature excess over ambient |
| `measured_current` | numeric | Measured current |
| `nominal_current` | numeric | Nominal current |
| `load_factor` | numeric | Load factor (`measured_current / nominal_current`) |
| `t_observed_excess` | numeric | Temperature excess over ambient (calculated) |
| `equipment_type_name` | text | Equipment type name |
| `is_panel` | text | `MOTOR` or `PANEL` based on equipment type |
| `detected_at` | timestamp | When defect was registered |
| `resolved_at` | timestamp | When defect was resolved |
| `defect_status` | text | Defect status |
| `full_name_major` | text | Senior inspector name |
| `position_major` | text | Senior inspector position |
| `full_names_minor` | text[] | Junior inspector names (from work log) |
| `positions_minor` | text[] | Junior inspector positions (from work log) |
| `started_at` | timestamp | Inspection date/time |
| `history_unit_name` | text[] | Historical unit names for this equipment |
| `history_detected_at` | timestamp[] | Historical defect detection dates |
| `history_t_sticker` | numeric[] | Historical sticker readings |
| `history_t_observed` | numeric[] | Historical thermal camera readings |
| `history_t_environment` | numeric[] | Historical ambient temperatures |
| `history_t_excess` | numeric[] | Historical temperature excess values |
| `t_sticker_min` | numeric | Parsed minimum sticker temperature |
| `t_sticker_excess` | numeric | Sticker temperature excess over maximum |

### Tables Referenced

- `lesiv.inspection` — Inspection records
- `lesiv.inspection_step` — Inspection step records (defect data)
- `lesiv.equipment_defect` — Equipment defect records
- `lesiv.equipment_detailed_view` — Equipment detailed view (hierarchy info)
- `lesiv.equipment` — Equipment records
- `lesiv.facility` — Facility records
- `lesiv.plant` — Plant records
- `lesiv.defect_type` — Defect type definitions
- `lesiv.sticker_type` — Sticker type definitions
- `lesiv.inspector` — Inspector information
- `lesiv.image` — Image records
- `lesiv.inspection_image_link` — Link between images and inspection steps
- `lesiv.work_log` — Work log records
- `lesiv.work_log_inspector` — Link between work logs and inspectors

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

## facility_list.sql

**Purpose:** Returns a list of all facilities (energy objects) within a selected plant for the `facility_name` parameter dropdown.

**Used for:** Enum query for the `facility_name` parameter in `metadata.yaml`.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:plant_name` | string | Yes | Plant name to filter facilities |

### Query Logic

- Joins `lesiv.facility` with `lesiv.plant` on `plant_id`
- Filters by non-deleted facility and plant
- Filters by `plant_name`
- Appends `-= ВСЕ =-` option to select all facilities
- Ordered alphabetically

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `name` | text | Facility name |

### Tables Referenced

- `lesiv.facility` — Facility records
- `lesiv.plant` — Plant records

---

## equipment_list.sql

**Purpose:** Returns a list of all equipment folders within a selected plant and facility for the `equipment_path` parameter dropdown.

**Used for:** Enum query for the `equipment_path` parameter in `metadata.yaml`.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:plant_name` | string | Yes | Plant name to filter equipment |
| `:facility_name` | string | Yes | Facility name to filter equipment |

### Query Logic

- Queries `lesiv.equipment_detailed_view` for equipment at depth ≤ 2
- Filters by non-deleted equipment and `is_container = true`
- Filters by plant and facility
- Appends `-= ВСЕ =-` option to select all equipment folders
- Ordered alphabetically

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `name` | text | Equipment folder name (equipment_path) |

### Tables Referenced

- `lesiv.equipment_detailed_view` — Equipment detailed view (hierarchy info)

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

#### `grouped_inspections` CTE
- Identifies equipment that was inspected during the reporting period
- Filters by non-deleted inspections

#### Final SELECT
- Joins inspected equipment with `equipment_detailed_view`
- Filters only leaf equipment (`is_container = false`)
- Aggregates total control points and sticker counts per facility/folder
- Formats folder name by replacing equipment path separators
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
