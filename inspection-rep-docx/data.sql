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
insp_history AS (
    SELECT 
        ed.equipment_id,
        ARRAY_AGG(ed.unit_name ORDER BY s.started_at DESC) AS unit_names,
        ARRAY_AGG(dt.t_excess ORDER BY s.started_at DESC) AS t_excess,
        ARRAY_AGG(s.started_at ORDER BY s.started_at DESC) AS unit_detected_at,
        ARRAY_AGG(s.t_sticker ORDER BY s.started_at DESC) AS t_stickers,
        ARRAY_AGG(s.t_observed ORDER BY s.started_at DESC) AS t_observed,
        ARRAY_AGG(s.t_environment ORDER BY s.started_at DESC) AS t_environments
    FROM lesiv.equipment_defect ed
        INNER JOIN lesiv.inspection_step AS s
            ON s.defect_id = ed.id
        INNER JOIN lesiv.defect_type AS dt	
            ON s.defect_type_id = dt.id
        INNER JOIN lesiv.equipment e ON ed.equipment_id = e.id
        INNER JOIN lesiv.facility f ON e.facility_id = f.id
        INNER JOIN lesiv.plant p ON p.id = f.plant_id
    WHERE p.name = :plant_name
        AND s.started_at >= '2026-01-01'::timestamp
        AND s.started_at < :period_start
    GROUP BY ed.equipment_id
),
work_log_data AS (
    SELECT
        wl.inspector_id,
        ARRAY_AGG(DISTINCT i2.full_name) AS full_names_minor,
        ARRAY_AGG(DISTINCT i2.position) AS positions_minor,
        wl.started_at,
        wl.completed_at
    FROM lesiv.work_log AS wl
    LEFT JOIN lesiv.work_log_inspector AS wli
        ON wli.work_log_id = wl.id
    LEFT JOIN lesiv.inspector AS i2
        ON i2.id = wli.inspector_id
    GROUP BY wl.id
),
base_table AS (
    SELECT 
        -- Столбец "Диспетчерское наименование электрооборудования; узел"
        edv.facility_name || ' > ' || edv.equipment_path AS full_equipment_name,
        -- "Узел" это следующие три столбца:
        dt.name AS defect_type_name,
        dt.short_name AS defect_type_short_name,
        s.unit_name,
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
        s.is_resolved,            -- Флаг устранения дефекта
        dt.t_max,                 -- Максимально допустимая температура для данного типа узла
        dt.t_excess,              -- Максимально допустимое превышение температуры над окр. средой.
        s.measured_current,       -- Измеренный ток
        s.nominal_current,        -- Номинальный ток
        CASE         	
        	WHEN s.measured_current <> 0 AND s.nominal_current <> 0
        	THEN s.measured_current * 1.0 / s.nominal_current 
        	ELSE NULL
        END as load_factor,       -- Коэффициент нагрузки
        s.t_observed - s.t_environment as t_observed_excess,         -- Повышение температуры над окр. средой
        --
        edv.equipment_type_name,                  -- Тип оборудования
        CASE WHEN edv.equipment_type_name LIKE '%двигатель%' THEN 'MOTOR' ELSE 'PANEL' END AS is_panel,
        d.detected_at,                            -- Когда дефект зарегистрирован
        d.status AS defect_status,                -- Статус дефекта
        ins.full_name AS full_name_major,         -- Кто проводил осмотр (старший инспектор)
        ins.position AS position_major,           -- Должность старшего инспектора
        wld.full_names_minor,                     -- Кто проводил осмотр (младшие инспектора)
        wld.positions_minor,                      -- Должности младших инспекторов
        i.started_at,                             -- дата осмотра
        hist.unit_names AS history_unit_names,    -- История осмотров (названия узлов)
        hist.unit_detected_at AS history_unit_detected_at,  -- История дат регистрации дефектов
        hist.t_stickers AS history_t_stickers,    -- История осмотров (стикеры)
        hist.t_observed AS history_t_observed,    -- История осмотров (тепловизор)
        hist.t_environments AS history_t_environment,  -- История осмотров (температура окружающей среды)
        hist.t_excess AS history_t_excess         -- История осмотров (превышение температуры)
    FROM 
        lesiv.inspection AS i
        INNER JOIN lesiv.inspection_step AS s
            ON s.inspection_id = i.id
        LEFT OUTER JOIN insp_history AS hist
            ON i.equipment_id = hist.equipment_id
        INNER JOIN lesiv.equipment_defect AS d
            ON d.id = s.defect_id
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
        INNER JOIN lesiv.inspector AS ins
            ON i.inspector_id = ins.id
        LEFT JOIN work_log_data AS wld
            ON wld.inspector_id = i.inspector_id
            AND i.started_at >= wld.started_at
            AND i.started_at < wld.completed_at
    WHERE
        i.started_at >= :period_start
        AND i.started_at < :period_end + interval '1 day'
        AND edv.plant_name = :plant_name
        AND (edv.facility_name = :facility_name OR :facility_name = '-= ВСЕ =-')
        AND (edv.equipment_path LIKE :equipment_path || '%' OR :equipment_path = '-= ВСЕ =-')
),
adjusted_temperatures AS
(
    SELECT
        *,
        -- Извлечение первой группы цифр из t_sticker (например, "100" из ">100" или "100-120")
        CASE
            WHEN t_sticker IS NOT NULL THEN
                CAST(NULLIF(substring(t_sticker from '\d+'), '') AS NUMERIC)
            ELSE NULL
        END as t_sticker_min
    FROM
        base_table
),
criticality_calc AS (
	SELECT
	    *,
        -- Превышение температуры по термоиндикаторной наклейке
	    CASE
	        WHEN t_sticker_min >= t_max THEN t_sticker_min - t_max 
	        ELSE 0
        END as t_sticker_excess
	FROM adjusted_temperatures
)
SELECT
	*
FROM criticality_calc
ORDER BY
	full_equipment_name,
	defect_type_name,
	unit_name