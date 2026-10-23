# SQL Queries Documentation

## data.sql

**Purpose:** Aggregates daily work statistics for inspectors — work hours, installation counts, and work log percentages over a reporting period.

**Used for:** Work tracking report — shows daily summary of inspector activity, including inspection work, installation (montage) work, and work completion percentages.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `:period_start` | date | Yes | Start of the reporting period |
| `:period_end` | date | Yes | End of the reporting period |
| `:act_number` | string | Yes | Report number |

### Query Logic

The query uses two CTEs and a generate_series to create a complete daily timeline:

#### `work_log_data` CTE — Work Log Aggregation
- Aggregates minor inspector names from work log entries
- Calculates work duration in hours using `EXTRACT(EPOCH FROM (completed_at - started_at)) / 3600`
- Retrieves installation percentage from work logs
- Groups by work log ID

#### `installation` CTE — Installation (Montage) Counts
- Counts sticker installations (`kind = 'INSTALLATION'`) per inspector per day
- Joins `sticker_installation` with `equipment_control_point` and `inspector`
- Filters by non-deleted control points
- Groups by day and inspector name

#### Final SELECT
- Uses `generate_series` to create a row for each day in the period
- Left joins with work logs to associate inspections with each day
- Joins with inspector and plant tables for metadata
- Left joins with installation counts to aggregate montage work per inspector per day
- Aggregates arrays of inspector names, plants, minor inspector names, montage counts, work hours, and work percentages per day
- Ordered by day ascending

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `day` | timestamp | Report date (one row per day in the period) |
| `full_name_major` | text[] | Array of senior inspector names |
| `plant_name` | text[] | Array of plant names |
| `full_names_minor` | text[] | Array of junior inspector name arrays (flattened) |
| `montage` | bigint[] | Array of installation counts per inspector |
| `work_hours` | numeric[] | Array of work hours per inspector |
| `work_percentage` | numeric[] | Array of work completion percentages |

### Tables Referenced

- `lesiv.work_log` — Work log records
- `lesiv.work_log_inspector` — Link between work logs and inspectors
- `lesiv.inspector` — Inspector information
- `lesiv.sticker_installation` — Sticker installation records
- `lesiv.equipment_control_point` — Equipment control points
- `lesiv.plant` — Plant records

---

## inspectors.sql

**Purpose:** Returns a list of all inspectors with their positions.

**Used for:** Populating inspector dropdowns or reference data in reports.

### Parameters

None.

### Query Logic

- Selects all non-deleted inspectors from `lesiv.inspector`
- Ordered alphabetically by full name

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `id` | integer | Inspector ID |
| `full_name` | text | Inspector full name |
| `position` | text | Inspector position |

### Tables Referenced

- `lesiv.inspector` — Inspector master data
