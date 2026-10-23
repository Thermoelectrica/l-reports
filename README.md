# L-Reports

Directory of report templates for the **L-Inspector** reporting system.

## Report Structure

Each report is a directory containing the following files:

### Required Files

1. **`metadata.yaml`** — Report configuration and parameters
2. **`index.html.j2`** — Jinja2 HTML template for rendering (required for `weasyprint` format)
3. **`*.sql`** — One or more SQL query files

### Optional Files

- **Template files** — DOCX/XLSX templates referenced in the template (e.g., `album_template_new.docx`, `act_template.xlsx`)
- **`CRIT_CALC.md`** — Criticality calculation rules (for inspection reports)
- **`plant_reference.json`** — Plant reference data (for inspection-act)
- **Images** — Logo files (e.g., `thermoelectrica_logo.png`)

### File Naming Rules

#### SQL Query Files

- **Naming Convention**: Use descriptive names with underscores (e.g., `table_stats.sql`, `columns.sql`)
- **Parameters**: Use named parameters with colon prefix (e.g., `:schema_name`, `:table_name`)
- **Type Casts**: PostgreSQL type casts (e.g., `::regclass`, `::integer`) are supported and won't be confused with parameters
- **No Positional Parameters**: Do NOT use positional parameters like `$1`, `$2` — always use named parameters
- **Enum Queries**: SQL files referenced by `enum_query` in metadata are used to populate parameter dropdowns

**Example SQL file:**
```sql
-- Good: Named parameters
SELECT * FROM pg_tables 
WHERE schemaname = COALESCE(:schema_name, 'public')
  AND tablename = :table_name;

-- Good: Type cast is preserved
SELECT (:schema_name || '.' || :table_name)::regclass;

-- Bad: Positional parameters are not allowed
SELECT * FROM pg_tables WHERE schemaname = $1;
```

#### Template Files

- **Name**: Must be `index.html.j2`
- **Format**: Jinja2 template with HTML

### Template Context

Templates receive the following context variables:

#### `globals` — Report Metadata
- `globals.template_name` — Report ID (directory name)
- `globals.report_name` — Human-readable report name from metadata
- `globals.generated_at` — ISO timestamp when report was generated
- `globals.version` — Report version from metadata

#### `params` — User Parameters
- Dictionary of user-provided parameter values
- Access via `params.parameter_name`
- Example: `{{ params.schema_name }}`, `{{ params.table_name }}`

#### `queries` — Query Results
- Dictionary where keys are SQL filenames (without `.sql` extension)
- Values are lists of row dictionaries
- Each row is a dictionary with column names as keys

**Example:**
```jinja2
{# Access query results from tables_list.sql #}
{% for row in queries.tables_list %}
  <tr>
    <td>{{ row.schema_name }}</td>
    <td>{{ row.table_name }}</td>
    <td>{{ row.total_size }}</td>
  </tr>
{% endfor %}

{# Check if query returned results #}
{% if queries.columns %}
  <h2>Columns ({{ queries.columns | length }})</h2>
{% endif %}
```

### Available Jinja2 Filters

- `format_number` — Format numbers with thousand separators: `{{ value | format_number }}`
- `format_date` — Format dates as YYYY-MM-DD: `{{ date | format_date }}`
- `format_datetime` — Format datetime as YYYY-MM-DD HH:MM:SS: `{{ datetime | format_datetime }}`
- `image_url` — Generate S3 presigned URL for remote images: `{{ 'path/to/image.jpg' | image_url }}`
- `local_image` — Embed local images as base64 data URIs: `{{ 'logo.png' | local_image }}`

### Using Local Images

You can embed images stored in the same directory as your template using the `local_image` filter. This is useful for logos, icons, or any static images that should be included in the report.

**Supported formats:** `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.bmp`

**Example usage:**
```jinja2
{# Simple image embedding #}
<img src="{{ 'logo.png' | local_image }}" alt="Company Logo">

{# Conditional image display #}
{% if 'header.jpg' | local_image %}
    <img src="{{ 'header.jpg' | local_image }}" alt="Header">
{% else %}
    <p>Header image not found</p>
{% endif %}

{# Dynamic image from query results #}
{% for item in queries.data %}
    {% if item.image_filename %}
        <img src="{{ item.image_filename | local_image }}" alt="{{ item.name }}">
    {% endif %}
{% endfor %}
```

**Example:** Place a file named `logo.png` in your report directory (e.g., `inspection-rep/thermoelectrica_logo.png`), then use it in your template with `{{ 'thermoelectrica_logo.png' | local_image }}`.

### Metadata File Format

```yaml
name: "Report Display Name"
description: "Optional description of what this report does"
version: "1.0"
timeout: 120  # Query timeout in seconds (optional)
cache_ttl_minutes: 10  # Cache TTL in minutes (optional, overrides global default of 5 minutes)
format: "pdf-protocol"  # Output format (optional)
preview: true  # Enable preview in UI (optional, default: false)

parameters:
  - name: schema_name
    type: string
    required: false
    description: "Database schema name"
    default: "public"
    placeholder: "Enter schema name"
    enum:
      - public
      - information_schema
    enum_query: "plant_list.sql"  # Load options from SQL file
```

#### Metadata Properties
- `name` — Human-readable report name (required)
- `description` — Detailed description of the report (optional)
- `version` — Report version string (default: "1.0")
- `timeout` — Maximum query execution time in seconds (optional)
- `cache_ttl_minutes` — Cache time-to-live in minutes for this specific report (optional)
- `format` — Output format (optional). Supported: `weasyprint`, `docxtpl`, `pdf-protocol`, `xlsx`, `xlsx-work`
- `preview` — Enable preview in UI (optional, default: false)
- `parameters` — List of parameter definitions (optional)

#### Parameter Types
- `string` — Text value
- `integer` — Whole number
- `float` — Decimal number
- `boolean` — True/False
- `date` — Date in ISO format (YYYY-MM-DD)
- `datetime` — Date and time in ISO format

#### Parameter Properties
- `name` — Parameter identifier (required)
- `type` — Data type (required)
- `required` — Whether parameter must be provided (default: false)
- `description` — Human-readable description (optional)
- `default` — Default value if not provided (optional)
- `placeholder` — Placeholder text for UI input (optional)
- `enum` — Static list of allowed values (optional)
- `enum_query` — SQL file to load allowed values from (optional)
- `visibility` — Hide parameter from UI (optional, default: true)

### Important Notes

1. **Parameters in Queries**: Not all parameters need to be used in every SQL query. Each query only binds the parameters it actually references.

2. **Reports Without Parameters**: Reports can have no parameters at all — just omit the `parameters` section in metadata.yaml or use an empty list.

3. **Query Results**: Query results are converted to lists of dictionaries. Access columns using dot notation or bracket notation in templates.

4. **Type Casts**: PostgreSQL type casts like `::regclass`, `::integer`, `::text` are properly handled and won't be mistaken for parameters.

5. **Enum Queries**: Use `enum_query` to populate parameter dropdowns from SQL results. The referenced SQL file should return a single column with available values.

6. **Hidden Parameters**: Use `visibility: false` to hide parameters from the UI while still providing default values (useful for device serial numbers, certificates, etc.).

## Available Reports

### inspection-rep
**Протокол теплового контроля (HTML, PDF)**
- Format: `weasyprint`
- Preview: enabled
- Description: Протокол теплового контроля контактов и контактных соединений с применением термоиндикаторов
- Parameters: `plant_name`, `period_start`, `period_end`, `protocol_number`, `include_developing`, `debug`, `thermal_device_*`
- Queries: `data.sql`, `plant_list.sql`, `inspection_dates.sql`, `inspection_summary.sql`

### inspection-rep-docx
**Протокол теплового контроля (DOCX)**
- Format: `docxtpl`
- Preview: disabled
- Description: Протокол теплового контроля контактов и контактных соединений с применением термоиндикаторов (DOCX output)
- Parameters: `plant_name`, `facility_name`, `equipment_path`, `period_start`, `period_end`, `protocol_number`, `include_developing`, `thermal_device_*`
- Queries: `data.sql`, `plant_list.sql`, `facility_list.sql`, `equipment_list.sql`, `inspection_dates.sql`, `inspection_summary.sql`
- Additional files: `album_template_new.docx`, `thermoelectrica_logo.png`

### inspection-express-pdf
**Протокол теплового контроля ежедневный (PDF)**
- Format: `pdf-protocol`
- Preview: disabled
- Description: Протокол теплового контроля ежедневного осмотра контактов и контактных соединений с применением термоиндикаторов
- Parameters: `plant_name`, `facility_name`, `equipment_path`, `period_start`, `period_end`, `protocol_number`, `include_developing`, `thermal_device_*`
- Queries: `data.sql`, `plant_list.sql`, `facility_list.sql`, `equipment_list.sql`, `inspection_dates.sql`, `inspection_summary.sql`
- Additional files: `album_template_new.docx`, `thermoelectrica_logo.png`

### inspection-dup-docx
**Отчет по дубликатам (DOCX)**
- Format: `docxtpl`
- Preview: disabled
- Description: Отчет по дубликатам дефектов, выявленных при осмотре оборудования
- Parameters: `plant_name`, `facility_name`, `equipment_path`, `protocol_number`, `include_developing`, `period_start`, `period_end`
- Queries: `data.sql`, `plant_list.sql`, `facility_list.sql`, `equipment_list.sql`
- Additional files: `album_template_new.docx`, `thermoelectrica_logo.png`

### inspection-act
**Технический акт (XLSX)**
- Format: `xlsx`
- Preview: disabled
- Description: Технический акт по сдаче-приемке услуг
- Parameters: `plant_name`, `period_start`, `period_end`, `act_number`, `protocol_number`, `service_type`
- Queries: `data.sql`, `plant_list.sql`
- Additional files: `act_template.xlsx`, `plant_reference.json`

### work-control-rep
**Учет работы (XLSX)**
- Format: `xlsx-work`
- Preview: disabled
- Description: Отчет о фактическом учете работы на станции
- Parameters: `period_start`, `period_end`, `act_number`
- Queries: `data.sql`, `inspectors.sql`

## Creating a New Report

1. Create a new directory in the root of the project
2. Add `metadata.yaml` with report configuration
3. Create SQL query files with named parameters
4. Create `index.html.j2` template using the context variables (required for `weasyprint` format)
5. Add any template files (DOCX/XLSX) if needed
6. Test the report through the UI

## Best Practices

- Use descriptive names for SQL files that indicate what data they fetch
- Keep SQL queries focused — one query per logical data set
- Use consistent styling in templates (see existing reports for examples)
- Add comments in SQL files to explain complex queries
- Test with various parameter combinations
- Handle empty query results gracefully in templates using `{% if queries.query_name %}`
- Use `enum_query` for dropdown parameters instead of hardcoding `enum` lists when values come from the database
- Use `visibility: false` for parameters that have defaults but don't need user input
