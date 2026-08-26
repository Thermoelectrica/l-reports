WITH ie AS (
    SELECT 
        i.equipment_id AS equipment_id,
        SUM(CASE WHEN sti.kind = 'INSTALLATION' THEN sti.count ELSE 0 END) AS sticker_count
    FROM lesiv.inspection AS i
    INNER JOIN lesiv.equipment_control_point AS ecp 
        ON ecp.equipment_id = i.equipment_id
    INNER JOIN lesiv.sticker_installation AS sti
        ON ecp.id = sti.control_point_id
    WHERE
        i.is_deleted IS FALSE
		AND ecp.is_deleted IS FALSE
        AND sti.installed_at BETWEEN :period_start AND cast(:period_end as timestamp) + interval '1 day'
	GROUP BY
        i.equipment_id
)
SELECT 
    edv.plant_name,
    REPLACE(edv.facility_name || ' > ' || edv.equipment_path, ' > ', ' ') AS equipment_path,
    ie.sticker_count
FROM lesiv.equipment_detailed_view edv	
INNER JOIN ie 
    ON ie.equipment_id = edv.id
WHERE 
    edv.plant_name = :plant_name;
