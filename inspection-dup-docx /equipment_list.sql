select name 
from
	(
		select edv.equipment_path as name
		from lesiv.equipment_detailed_view edv
		where 
			edv.equipment_depth <= 2
            and edv.is_container
			and not(edv.is_deleted)
			and plant_name = :plant_name
			and EXISTS (
			    SELECT 1 FROM lesiv.inspector_plant_access ipa
			    WHERE ipa.plant_id = edv.plant_id
			      AND ipa.inspector_id = CAST(:current_inspector_id AS integer)
			)
			and (facility_name = :facility_name)
		union all
		select '-= ВСЕ =-'
	)
order by name