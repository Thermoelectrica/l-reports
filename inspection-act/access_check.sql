-- Проверка доступа к отчёту (metadata.yaml -> access_query).
-- TRUE только если станция с таким именем существует и у инспектора есть доступ
-- ко ВСЕМ станциям с этим именем (имя не уникально, а основные запросы
-- фильтруют по имени). Неизвестный инспектор (NULL) -> FALSE.
SELECT
    EXISTS (
        SELECT 1 FROM lesiv.plant p WHERE p.name = :plant_name
    )
    AND NOT EXISTS (
        SELECT 1
        FROM lesiv.plant p
        WHERE p.name = :plant_name
          AND NOT EXISTS (
              SELECT 1
              FROM lesiv.inspector_plant_access ipa
              WHERE ipa.plant_id = p.id
                AND ipa.inspector_id = CAST(:current_inspector_id AS integer)
          )
    ) AS has_access
