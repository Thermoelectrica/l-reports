WITH grouped_inspections AS (
    SELECT
        ins.equipment_id
    FROM lesiv.inspection AS ins
    WHERE ins.started_at >= :period_start
        AND ins.started_at < :period_end + interval '1 day'
        AND ins.is_deleted = false
    GROUP BY ins.equipment_id
)
SELECT
    edv.facility_name,
    REPLACE(REPLACE(edv.equipment_path, ' > ' || edv.name, ''),' >',' -') AS full_folder_name,
    SUM(edv.total_point_count) AS total_point_count,
    SUM(edv.total_sticker_count) AS total_sticker_count
FROM
    lesiv.equipment_detailed_view AS edv
    INNER JOIN grouped_inspections AS fi
        ON edv.id = fi.equipment_id
WHERE
    edv.is_container = false
    AND edv.plant_name = :plant_name
GROUP BY
    full_folder_name,
    edv.facility_name
ORDER BY
    edv.facility_name,
    full_folder_name