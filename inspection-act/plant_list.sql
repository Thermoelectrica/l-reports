SELECT p.name
FROM lesiv.plant p
WHERE NOT p.is_deleted
  AND EXISTS (
      SELECT 1
      FROM lesiv.inspector_plant_access ipa
      WHERE ipa.plant_id = p.id
        AND ipa.inspector_id = :current_inspector_id
  )
ORDER BY p.name ASC
