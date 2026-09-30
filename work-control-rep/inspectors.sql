SELECT 
        i.id,
        i.full_name
    FROM lesiv.inspector AS i
WHERE
    i.is_deleted IS FALSE
ORDER BY i.full_name ASC
   