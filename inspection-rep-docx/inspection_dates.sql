SELECT DISTINCT
    DATE(i.started_at) as inspection_date
FROM
    lesiv.inspection AS i
    INNER JOIN lesiv.equipment_detailed_view AS edv
        ON i.equipment_id = edv.id
WHERE
    i.started_at BETWEEN :period_start AND :period_end
    AND edv.plant_name = :plant_name
    AND EXISTS (
        SELECT 1 FROM lesiv.inspector_plant_access ipa
        WHERE ipa.plant_id = edv.plant_id
          AND ipa.inspector_id = CAST(:current_inspector_id AS integer)
    )
ORDER BY
    inspection_date
