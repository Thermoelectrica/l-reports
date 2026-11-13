SELECT 
    i.id,
    i.full_name,
    i.is_internal,
    i."access_level",
    COALESCE(ARRAY_AGG(p.name ORDER BY p.name), ARRAY[]::text[]) AS plant_names
FROM lesiv.inspector AS i
LEFT JOIN lesiv.inspector_plant_access AS ipa
    ON ipa.inspector_id = i.id
LEFT JOIN lesiv.plant AS p
    ON p.id = ipa.plant_id
WHERE
    i.is_deleted IS FALSE
    AND i.id = :user_id::integer
GROUP BY 
    i.id, 
    i.full_name, 
    i.is_internal, 
    i."access_level"