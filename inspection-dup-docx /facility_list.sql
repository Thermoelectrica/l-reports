SELECT name 
FROM 
(
    SELECT 
        f.name 
    FROM 
        lesiv.facility f
        INNER JOIN lesiv.plant p
            ON f.plant_id = p.id
    WHERE 
        not(f.is_deleted)
        AND not(p.is_deleted) 
        AND p.name = :plant_name   
        AND EXISTS (
            SELECT 1 FROM lesiv.inspector_plant_access ipa
            WHERE ipa.plant_id = p.id
              AND ipa.inspector_id = CAST(:current_inspector_id AS integer)
        )
    UNION ALL
    SELECT '-= ВСЕ =-'
) f
ORDER BY 
    name