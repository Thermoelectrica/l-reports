WITH inspector AS (
    SELECT 
        i.id,
        i.full_name
    FROM lesiv.inspector AS i
),
work_log_data AS (
    SELECT
        wl.id AS work_log_id,
        ARRAY_AGG(DISTINCT i.full_name) AS full_names_minor,
        wl.started_at,
        wl.completed_at,
        EXTRACT(EPOCH FROM (wl.completed_at - wl.started_at)) / 3600 AS work_hours,  -- часы
        wl.installation_percentage as work_percentage
    FROM lesiv.work_log AS wl
    LEFT JOIN lesiv.work_log_inspector AS wli
        ON wli.work_log_id = wl.id
    LEFT JOIN lesiv.inspector AS i
        ON i.id = wli.inspector_id
    GROUP BY 
        wl.id, 
        wl.started_at, 
        wl.completed_at,
        wl.installation_percentage
),
installation AS (
    SELECT 
        date_trunc('day', sti.installed_at) AS day,
        i.full_name,
        SUM(CASE WHEN sti.kind = 'INSTALLATION' THEN sti.count ELSE 0 END) AS montage
    FROM lesiv.sticker_installation AS sti
    INNER JOIN lesiv.equipment_control_point AS ecp 
        ON ecp.id = sti.control_point_id
    INNER JOIN lesiv.inspector AS i
        ON i.id = sti.inspector_id
    WHERE
        ecp.is_deleted IS FALSE
    GROUP BY
        date_trunc('day', sti.installed_at),
        i.full_name
)
SELECT 
    gs.day,
    ARRAY_AGG(ins.full_name) AS major_names,
    ARRAY_AGG(pl.name) AS plant_name,
    ARRAY_AGG(COALESCE(wld.full_names_minor, ARRAY[]::text[])) AS minor_names,
    ARRAY_AGG(inst.montage) AS montage,
    ARRAY_AGG(wld.work_hours) AS work_hours,
    ARRAY_AGG(wld.work_percentage) AS work_percentage
FROM generate_series(
    :period_start,
    :period_end,
    interval '1 day'
) AS gs(day)
LEFT JOIN lesiv.work_log AS wl
    ON wl.started_at >= gs.day
    AND wl.started_at < gs.day + interval '1 day'
INNER JOIN inspector AS ins
    ON wl.inspector_id = ins.id
LEFT JOIN work_log_data AS wld
    ON wld.work_log_id = wl.id
LEFT JOIN installation AS inst
    ON gs.day = inst.day
    AND ins.full_name = inst.full_name
INNER JOIN lesiv.plant AS pl
    ON wl.plant_id = pl.id
GROUP BY gs.day
ORDER BY gs.day ASC