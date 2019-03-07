CREATE OR REPLACE FUNCTION contacts.group_people_add(IN _owner character VARYING, IN _group_id int8, IN _people_ids int8[])
  RETURNS int8 AS
$BODY$
DECLARE
	_selected_cnt int8 = 0;
	_inserted_cnt int8 = 0;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	SELECT 1 FROM contacts."group" g
	WHERE g.id = _group_id AND g.owner = _owner INTO _selected_cnt;

	IF _selected_cnt > 0 THEN		
		WITH affected_rows AS (
			INSERT INTO contacts.belongs (owner, person_id,	group_id)
				(SELECT
					_owner,
					person_id,
					_group_id
				FROM unnest(_people_ids) person_id)
				--ON CONFLICT DO NOTHING
				ON CONFLICT ON CONSTRAINT belongs_person_group_unique DO NOTHING
				RETURNING 1
		) SELECT COUNT(*) INTO _inserted_cnt
			FROM affected_rows;		
		RETURN _inserted_cnt;
	ELSE
		RETURN -1; -- _group_id not found	
	END IF;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

--SELECT contacts.group_people_add('jdoe@leadict.com', 2, '{1, 2, 3, 4}');

CREATE OR REPLACE FUNCTION contacts.group_people_remove(IN _owner character VARYING, IN _group_id int8, IN _people_ids int8[])
  RETURNS int8 AS
$BODY$
DECLARE
	_selected_cnt int8 = 0;
	_removed_cnt int8 = 0;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	SELECT 1 FROM contacts."group" g
	WHERE g.id = _group_id AND g.owner = _owner INTO _selected_cnt;

	IF _selected_cnt > 0 THEN		
		WITH affected_rows AS (
			DELETE FROM contacts.belongs b
				WHERE b.group_id = _group_id AND b.owner = _owner AND b.person_id = ANY(_people_ids)
				RETURNING 1
		) SELECT COUNT(*) INTO _removed_cnt
			FROM affected_rows;		
		RETURN _removed_cnt;
	ELSE
		RETURN -1; -- _group_id not found	
	END IF;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

--SELECT contacts.group_people_remove('jdoe@leadict.com', 2, '{1, 2, 3, 4, 5, 6, 7}');