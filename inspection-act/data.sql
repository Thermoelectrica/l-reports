WITH rev AS (
    SELECT 
        i.equipment_id AS equipment_id,
        SUM(sti.count) AS inspection
    FROM lesiv.inspection AS i
    INNER JOIN lesiv.equipment_control_point AS ecp 
        ON ecp.equipment_id = i.equipment_id
    INNER JOIN lesiv.sticker_installation AS sti
        ON ecp.id = sti.control_point_id
    WHERE
        i.is_deleted IS FALSE
        AND ecp.is_deleted IS FALSE
        AND sti.installed_at >= :period_start
        AND sti.installed_at < :period_end + interval '1 day'
	GROUP BY
        i.equipment_id
),
ins AS (
    SELECT 
        ecp.equipment_id AS equipment_id,
        SUM(CASE WHEN sti.kind = 'INSTALLATION' THEN sti.count ELSE 0 END) AS montage
    FROM lesiv.sticker_installation AS sti
    INNER JOIN lesiv.equipment_control_point AS ecp 
        ON ecp.id = sti.control_point_id
    WHERE
        ecp.is_deleted IS FALSE
        AND sti.installed_at >= :period_start
        AND sti.installed_at < :period_end + interval '1 day'
	GROUP BY
        ecp.equipment_id
)
SELECT 
    edv.plant_name,
    REPLACE(edv.facility_name || ' > ' || edv.equipment_path, ' > ', ' ') AS equipment_path,
    rev.inspection,
    ins.montage
FROM lesiv.equipment_detailed_view edv	
LEFT JOIN rev
    ON rev.equipment_id = edv.id
LEFT JOIN ins 
    ON ins.equipment_id = edv.id
WHERE 
    edv.plant_name = :plant_name
    AND (rev.inspection IS NOT NULL OR ins.montage IS NOT NULL);
