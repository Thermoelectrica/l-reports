WITH work_log_data AS (
    SELECT
        wl.id AS work_log_id,
        ARRAY_AGG(DISTINCT i2.full_name) AS full_names_minor,
        wl.started_at,
        wl.completed_at,
        EXTRACT(EPOCH FROM (wl.completed_at - wl.started_at)) / 3600 AS work_hours,
        wl.installation_percentage as work_percentage
    FROM lesiv.work_log AS wl
    LEFT JOIN lesiv.work_log_inspector AS wli
        ON wli.work_log_id = wl.id
    LEFT JOIN lesiv.inspector AS i2
        ON i2.id = wli.inspector_id
    GROUP BY 
        wl.id, 
        wl.started_at, 
        wl.completed_at,
        wl.installation_percentage
),
installation AS (
    SELECT 
        date_trunc('day', sti.installed_at) AS day,
        i3.full_name,
        SUM(CASE WHEN sti.kind = 'INSTALLATION' THEN sti.count ELSE 0 END) AS montage
    FROM lesiv.sticker_installation AS sti
    INNER JOIN lesiv.equipment_control_point AS ecp 
        ON ecp.id = sti.control_point_id
    INNER JOIN lesiv.inspector AS i3
        ON i3.id = sti.inspector_id
    WHERE
        ecp.is_deleted IS FALSE
    GROUP BY
        date_trunc('day', sti.installed_at),
        i3.full_name
),
inspection_stats AS (
    -- Завершенные осмотры и охваченные ими контрольные точки
    -- за день по инспектору
    SELECT
        date_trunc('day', insp.started_at) AS day,
        insp.inspector_id,
        COUNT(*) AS completed_inspections,
        COALESCE(SUM(cp.point_count), 0) AS control_points
    FROM lesiv.inspection AS insp
    LEFT JOIN (
        SELECT
            ecp.equipment_id,
            SUM(ecp.point_count) AS point_count
        FROM lesiv.equipment_control_point AS ecp
        WHERE ecp.is_deleted IS FALSE
        GROUP BY ecp.equipment_id
    ) AS cp
        ON cp.equipment_id = insp.equipment_id
    WHERE
        insp.is_deleted IS FALSE
        AND insp.status = 'COMPLETED'
    GROUP BY
        date_trunc('day', insp.started_at),
        insp.inspector_id
)
SELECT 
    gs.day,
    ARRAY_AGG(ins.full_name) AS full_name_major,
    ARRAY_AGG(pl.name) AS plant_name,
    ARRAY_AGG(COALESCE(wld.full_names_minor, ARRAY[]::text[])) AS full_names_minor,
    ARRAY_AGG(inst.montage) AS montage,
    ARRAY_AGG(wld.work_hours) AS work_hours,
    ARRAY_AGG(wld.work_percentage) AS work_percentage,
    ARRAY_AGG(COALESCE(ist.control_points, 0)) AS control_points,
    ARRAY_AGG(COALESCE(ist.completed_inspections, 0)) AS completed_inspections
FROM generate_series(
    :period_start,
    :period_end,
    interval '1 day'
) AS gs(day)
LEFT JOIN lesiv.work_log AS wl
    ON wl.started_at >= gs.day
    AND wl.started_at < gs.day + interval '1 day'
INNER JOIN lesiv.inspector AS ins
    ON wl.inspector_id = ins.id
LEFT JOIN work_log_data AS wld
    ON wld.work_log_id = wl.id
LEFT JOIN installation AS inst
    ON gs.day = inst.day
    AND ins.full_name = inst.full_name
LEFT JOIN inspection_stats AS ist
    ON gs.day = ist.day
    AND ins.id = ist.inspector_id
INNER JOIN lesiv.plant AS pl
    ON wl.plant_id = pl.id
GROUP BY gs.day
ORDER BY gs.day ASC