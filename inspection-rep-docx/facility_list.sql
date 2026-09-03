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
    UNION ALL
    SELECT '-= ВСЕ =-'
) f
ORDER BY 
    name