WITH rev AS (
    SELECT 
        COUNT(ist.id) AS inspection,
        i.equipment_id
    FROM lesiv.inspection AS i
    LEFT JOIN lesiv.inspection_step AS ist
        ON i.id = ist.inspection_id
        AND ist.is_deleted IS FALSE
    WHERE
        i.is_deleted IS FALSE
        AND i.started_at >= :period_start
        AND i.started_at < :period_end + interval '1 day'
        AND i.status = 'COMPLETED'
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
