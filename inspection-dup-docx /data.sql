WITH grouped_images AS (
	SELECT
	 	il.inspection_step_id,
	 	i."image_type",
	 	array_agg(cast(image_id as TEXT) || '.jpg') as image_ids
	FROM
		lesiv.inspection_image_link AS il
		INNER JOIN lesiv.image AS i
	 		ON il.image_id = i.id
    WHERE i.original_file_name NOT LIKE '%CCD%'
	GROUP BY il.inspection_step_id, i."image_type"
),
defect_duplicate AS (
    SELECT 
        ed.id as defect_id,
        ed.equipment_id
    FROM lesiv.equipment_defect ed
        JOIN (
            SELECT 
                equipment_id,
                unit_name,
                COUNT(*) AS cnt
            FROM lesiv.equipment_defect
            WHERE status = 'DETECTED'
            GROUP BY equipment_id, unit_name
            HAVING COUNT(*) > 1
        ) dup ON ed.equipment_id = dup.equipment_id 
              AND ed.unit_name = dup.unit_name
    WHERE ed.status = 'DETECTED'
),
base_table AS (
    SELECT 
        -- Столбец "Диспетчерское наименование электрооборудования; узел"
        edv.facility_name || ' > ' || edv.equipment_path AS full_equipment_name,
        -- "Узел" это следующие три столбца:
        dt.name AS defect_type_name,
        dt.short_name AS defect_type_short_name,
        COALESCE(s.unit_name, ' --- ') AS unit_name,
        -- Столбец "Фотография термоиндикатора и термограмма"
        vil.image_ids AS visual_image_ids,
        til.image_ids AS thermal_image_ids,
        -- Столбец "Выявленный дефект"
        s.is_sticker_present,     -- Есть ли ТИН (термоиндикаторная наклейка)
        st.name AS sticker_name,  -- Тип наклейки 
        s.t_sticker,              -- Показания наклейки 
        s.is_test_ready,          -- Контролепригодно или нет
        s.t_environment,          -- Температура окружающей среды
        s.t_similar_unit,         -- Температура аналогичного узла
        s.t_observed,             -- Температура, зарегистрированная тепловизором
        s.is_attention_required,  -- Необходимость внимания
        dt.t_max,                 -- Максимально допустимая температура для данного типа узла
        dt.t_excess,              -- Максимально допустимое превышение температуры над окр. средой.
        s.measured_current,       -- Измеренный ток
        s.nominal_current,        -- Номинальный ток
        s.t_observed - s.t_environment as t_observed_excess,         -- Повышение температуры над окр. средой
        edv.equipment_type_name,  -- Тип оборудования
        CASE WHEN edv.equipment_type_name LIKE '%двигатель%' THEN 'MOTOR' ELSE 'PANEL' END AS is_panel,
        ins.full_name AS inspector_name, -- Кто проводил осмотр
        i.started_at AS inspection_date  -- Когда проводился осмотр
    FROM 
        lesiv.inspection AS i
        INNER JOIN lesiv.inspection_step AS s
            ON s.inspection_id = i.id
        INNER JOIN lesiv.equipment_defect AS d
            ON d.id = s.defect_id 
            AND d.id IN (SELECT defect_id FROM defect_duplicate)
        INNER JOIN lesiv.equipment_detailed_view AS edv
            ON i.equipment_id = edv.id
        INNER JOIN lesiv.defect_type AS dt	
            ON s.defect_type_id = dt.id
        LEFT OUTER JOIN lesiv.sticker_type AS st
            ON s.sticker_type_id = st.id
        LEFT OUTER JOIN grouped_images AS vil
            ON s.id = vil.inspection_step_id AND vil.image_type = 'VISUAL'
        LEFT OUTER JOIN grouped_images AS til
            ON s.id = til.inspection_step_id AND til.image_type = 'THERMAL'	
        LEFT OUTER JOIN lesiv.inspector AS ins
            ON i.inspector_id = ins.id	
    WHERE
        i.started_at BETWEEN :period_start AND cast(:period_end as timestamp) + interval '1 day' 
        AND edv.plant_name = :plant_name
        AND (edv.facility_name = :facility_name OR :facility_name = '-= ВСЕ =-')
        AND (edv.equipment_path LIKE :equipment_path || '%' OR :equipment_path = '-= ВСЕ =-')
)
SELECT
	*
FROM base_table
ORDER BY
	full_equipment_name,
    defect_type_name,
    unit_name