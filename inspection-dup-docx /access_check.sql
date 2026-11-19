-- Проверка доступа к отчёту (metadata.yaml -> access_query).
-- Возвращает одну строку с plant_ids, только если станция с таким именем существует
-- и у инспектора есть доступ ко ВСЕМ станциям с этим именем (имя не уникально).
-- Иначе 0 строк -> движок отказывает в доступе.
-- plant_ids движок передаёт в основные запросы как параметр plant_ids (фильтр plant_id = ANY(...))
SELECT
    array_agg(p.id ORDER BY p.id) AS plant_ids
FROM lesiv.plant p
    LEFT JOIN lesiv.inspector_plant_access ipa
        ON ipa.plant_id = p.id
        AND ipa.inspector_id = :current_inspector_id
WHERE
    p.name = :plant_name
HAVING
    bool_and(ipa.plant_id IS NOT NULL)
