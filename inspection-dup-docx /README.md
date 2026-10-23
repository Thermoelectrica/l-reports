# SQL Queries Documentation

## data.sql

**Purpose:** Retrieves duplicate defects detected during inspections. A duplicate is defined as multiple defects with the same `equipment_id` and `unit_name` and status `DETECTED`.

**Used for:** Duplicate defects report — lists equipment with repeated defects found during the reporting period.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:plant_name` | string | Yes | Plant/facility name |
| `:facility_name` | string | Yes | Equipment facility name (use `-= ВСЕ =-` for all) |
| `:equipment_path` | string | Yes | Equipment path/folder (use `-= ВСЕ =-` for all) |
| `:period_start` | date | Yes | Start of the reporting period |
| `:period_end` | date | Yes | End of the reporting period |

### Query Logic

The query uses three CTEs to aggregate and filter data:

#### `grouped_images` CTE — Image Aggregation
- Groups image IDs by `inspection_step_id` and `image_type`
- Concatenates image IDs with `.jpg` extension into an array
- Excludes images with `CCD` in the original filename
- Separates images into VISUAL and THERMAL types

#### `defect_duplicate` CTE — Duplicate Detection
- Identifies defects with duplicate `equipment_id` + `unit_name` combinations
- Filters only defects with `status = 'DETECTED'`
- Uses `HAVING COUNT(*) > 1` to find duplicates

#### `base_table` CTE — Main Data Assembly
- Joins inspection data with defect, equipment, and sticker information
- Concatenates facility and equipment paths for display (`full_equipment_name`)
- Extracts defect type info (`name`, `short_name`)
- Assembles visual and thermal image arrays from `grouped_images`
- Calculates temperature excess: `t_observed - t_environment`
- Determines equipment type: `MOTOR` or `PANEL` based on equipment name
- Includes inspector name and inspection date

#### Final SELECT
- Returns all columns from `base_table`
- Ordered by equipment name, defect type, and unit name

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `full_equipment_name` | text | Facility + equipment path concatenated with ` > ` |
| `defect_type_name` | text | Full defect type name |
| `defect_type_short_name` | text | Short defect type name |
| `unit_name` | text | Unit name (or ` --- ` if not set) |
| `visual_image_ids` | text[] | Array of visual image filenames (e.g., `['123.jpg', '456.jpg']`) |
| `thermal_image_ids` | text[] | Array of thermal image filenames |
| `is_sticker_present` | boolean | Whether thermo-indicator sticker is present |
| `sticker_name` | text | Sticker type name |
| `t_sticker` | numeric | Sticker temperature reading |
| `is_test_ready` | boolean | Testable or not |
| `t_environment` | numeric | Ambient temperature |
| `t_similar_unit` | numeric | Similar unit temperature |
| `t_observed` | numeric | Temperature registered by thermal camera |
| `is_attention_required` | boolean | Whether attention is required |
| `t_max` | numeric | Maximum allowed temperature for defect type |
| `t_excess` | numeric | Maximum allowed temperature excess over ambient |
| `measured_current` | numeric | Measured current |
| `nominal_current` | numeric | Nominal current |
| `t_observed_excess` | numeric | Temperature excess over ambient (calculated) |
| `equipment_type_name` | text | Equipment type name |
| `is_panel` | text | `MOTOR` or `PANEL` based on equipment type |
| `inspector_name` | text | Name of the inspector |
| `inspection_date` | timestamp | Date of inspection |

### Tables Referenced

- `lesiv.inspection` — Inspection records
- `lesiv.inspection_step` — Inspection step records (defect data)
- `lesiv.equipment_defect` — Equipment defect records
- `lesiv.equipment_detailed_view` — Equipment detailed view (hierarchy info)
- `lesiv.equipment_control_point` — Equipment control points
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
