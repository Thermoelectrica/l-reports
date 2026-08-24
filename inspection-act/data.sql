WITH ie AS (
	SELECT 
		equipment_id,
		sum(CASE WHEN sti.kind = 'INSTALLATION' THEN sti.count ELSE 0 END) AS sticker_count
	FROM
		lesiv.inspection AS i	
		INNER JOIN lesiv.inspection_step AS step
			ON i.id = step.inspection_id
		INNER JOIN lesiv.sticker_installation AS sti
			ON i.equipment_id = sti.control_point_id
    WHERE
	    i.is_deleted IS FALSE
        AND sti.installed_at BETWEEN :period_start AND cast(:period_end as timestamp) + interval '1 day'
	GROUP BY
		equipment_id
)
SELECT 
	edv.plant_name,
	REPLACE(edv.facility_name || ' > ' || edv.equipment_path, ' > ', ' ') AS equipment_path,
	sticker_count
FROM
	lesiv.equipment_detailed_view edv	
	INNER JOIN ie ON
		ie.equipment_id = edv.id
WHERE 
    edv.plant_name = :plant_name