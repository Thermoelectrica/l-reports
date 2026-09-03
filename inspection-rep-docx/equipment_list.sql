select name 
from
	(
		select edv.equipment_path as name
		from lesiv.equipment_detailed_view edv
		where 
			edv.equipment_depth <= 2
			and not(edv.is_deleted)
			and plant_name = :plant_name
			and (facility_name = :facility_name)
		union all
		select '-= ВСЕ =-'
	)
order by name