# SQL Queries Documentation

## data.sql

**Purpose:** Retrieves inspection and installation (montage) counts per equipment for a given plant and period.

**Used for:** Technical act report — lists equipment that had inspections or sticker installations during the reporting period.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:plant_name` | string | Yes | Plant/facility name |
| `:period_start` | date | Yes | Start of the reporting period |
| `:period_end` | date | Yes | End of the reporting period |

### Query Logic

The query uses two CTEs to aggregate data:

#### `rev` CTE — Inspections
- Counts completed inspections (`status = 'COMPLETED'`) per equipment
- Joins `inspection` with `inspection_step` (only non-deleted steps)
- Filters by `started_at` within the reporting period
- Groups by `equipment_id`

#### `ins` CTE — Installations (Montage)
- Counts sticker installations (`kind = 'INSTALLATION'`) per equipment
- Joins `sticker_installation` with `equipment_control_point`
- Filters by `installed_at` within the reporting period
- Groups by `equipment_id`

#### Final SELECT
- Joins both CTEs with `equipment_detailed_view` (`edv`)
- Returns only equipment that had **at least one inspection OR installation** during the period (`rev.inspection IS NOT NULL OR ins.montage IS NOT NULL`)
- Equipment path is formatted by concatenating facility and equipment, removing intermediate ` > ` separators

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `plant_name` | text | Name of the plant |
| `equipment_path` | text | Formatted equipment path (facility + equipment, flattened) |
| `inspection` | bigint | Number of completed inspections during the period |
| `montage` | bigint | Number of sticker installations during the period |

### Tables Referenced

- `lesiv.inspection` — Inspection records
- `lesiv.inspection_step` — Inspection step records
- `lesiv.sticker_installation` — Sticker installation records
- `lesiv.equipment_control_point` — Equipment control points
- `lesiv.equipment_detailed_view` — Equipment detailed view (hierarchy info)

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
