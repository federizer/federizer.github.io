CREATE OR REPLACE FUNCTION filters.create_filter(IN _owner character varying, IN _name character varying, IN _criteria text, IN _postal_labels jsonb, IN _add_custom_label_ids int8[], IN _remove_custom_label_ids int8[])
  RETURNS TABLE(id int8,
                name character varying,
                criteria text,
                postal_label jsonb,
                add_custom_label_ids jsonb,
                remove_custom_label_ids jsonb) AS
$BODY$
BEGIN
	RETURN QUERY SELECT * FROM filters.upsert_filter(_owner, NULL, _name, _criteria, _postal_labels, _add_custom_label_ids, _remove_custom_label_ids); 
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION filters.update_filter(IN _owner character varying, IN _filter_id int8, IN _name character varying, IN _criteria text, IN _postal_labels jsonb, IN _add_custom_label_ids int8[], IN _remove_custom_label_ids int8[])
  RETURNS TABLE(id int8,
                name character varying,
                criteria text,
                postal_label jsonb,
                add_custom_label_ids jsonb,
                remove_custom_label_ids jsonb) AS
$BODY$
BEGIN
	RETURN QUERY SELECT * FROM filters.upsert_filter(_owner, _filter_id, _name, _criteria, _postal_labels, _add_custom_label_ids, _remove_custom_label_ids); 
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION filters.upsert_filter(IN _owner character varying, IN _filter_id int8, IN _name character varying, IN _criteria text, IN _postal_labels jsonb, IN _add_custom_label_ids int8[], IN _remove_custom_label_ids int8[])
  RETURNS TABLE(id int8,
                name character varying,
                criteria text,
                postal_label jsonb,
                add_custom_label_ids jsonb,
                remove_custom_label_ids jsonb) AS
$BODY$
DECLARE
	_rec record;
	_inserted_filter_id int8;
	_inserted_postal_label_action_id int8;
	_inserted_custom_label_action_add_cnt int8;
	_inserted_custom_label_action_remove_cnt int8;
	_filter_cnt int8;
	_postal_label_action_cnt int8;
	_jsonb_array jsonb := '[]';
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	IF _filter_id IS NULL THEN
		INSERT INTO filters.filter (owner,
									 name,
									 criteria)
		    VALUES (_owner,
				   _name,
				   _criteria
			) RETURNING filters.filter.id INTO _inserted_filter_id;

		INSERT INTO filters.postal_label_action (owner,
									 filter_id,
									 done,
									 archived,
									 starred,
									 important,
									 chats,
									 spam,
									 unread,
									 trash)
		    VALUES (_owner,
				   _inserted_filter_id,
				   (_postal_labels->>'done')::boolean,
				   (_postal_labels->>'archived')::boolean,
				   (_postal_labels->>'starred')::boolean,
				   (_postal_labels->>'important')::boolean,
				   (_postal_labels->>'chats')::boolean,
				   (_postal_labels->>'spam')::boolean,
				   (_postal_labels->>'unread')::boolean,
				   (_postal_labels->>'trash')::boolean
			) RETURNING filters.postal_label_action.id INTO _inserted_postal_label_action_id;
		
		WITH affected_rows AS (
			INSERT INTO filters.custom_label_action (owner, filter_id, custom_label_id, custom_label_action)
				(SELECT
					_owner,
					_inserted_filter_id,
					custom_label_id,
					'add'::filters.custom_label_actions
				FROM unnest(_add_custom_label_ids) custom_label_id)
				--ON CONFLICT DO NOTHING
				ON CONFLICT ON CONSTRAINT custom_label_action_filter_custom_label_unique DO NOTHING
				RETURNING 1
		) SELECT COUNT(*) INTO _inserted_custom_label_action_add_cnt
			FROM affected_rows;
				
		WITH affected_rows AS (
			INSERT INTO filters.custom_label_action (owner, filter_id, custom_label_id, custom_label_action)
				(SELECT
					_owner,
					_inserted_filter_id,
					custom_label_id,
					'remove'::filters.custom_label_actions
				FROM unnest(_remove_custom_label_ids) custom_label_id)
				--ON CONFLICT DO NOTHING
				ON CONFLICT ON CONSTRAINT custom_label_action_filter_custom_label_unique DO NOTHING
				RETURNING 1
		) SELECT COUNT(*) INTO _inserted_custom_label_action_remove_cnt
			FROM affected_rows;
	ELSE
   		WITH affected_rows AS (
			UPDATE filters.filter f
				SET name = _name,
					criteria = _criteria
				WHERE f.id = _filter_id AND f."owner" = _owner RETURNING 1
		) SELECT COUNT(*) INTO _filter_cnt
			FROM affected_rows;	

		IF _filter_cnt > 0 THEN
			WITH affected_rows AS (
				UPDATE filters.postal_label_action pla
					SET done = (_postal_labels->>'done')::boolean,
						archived = (_postal_labels->>'archived')::boolean,
						starred = (_postal_labels->>'starred')::boolean,
						important = (_postal_labels->>'important')::boolean,
						chats = (_postal_labels->>'chats')::boolean,
						spam = (_postal_labels->>'spam')::boolean,
						unread = (_postal_labels->>'unread')::boolean,
						trash = (_postal_labels->>'trash')::boolean
					WHERE pla.filter_id = _filter_id AND pla."owner" = _owner RETURNING 1
			) SELECT COUNT(*) INTO _postal_label_action_cnt
				FROM affected_rows;
			
			DELETE FROM filters.custom_label_action
			WHERE filters.custom_label_action.filter_id = _filter_id;

			WITH affected_rows AS (
				INSERT INTO filters.custom_label_action (owner, filter_id, custom_label_id, custom_label_action)
					(SELECT
						_owner,
						_filter_id,
						custom_label_id,
						'add'::filters.custom_label_actions
					FROM unnest(_add_custom_label_ids) custom_label_id)
					--ON CONFLICT DO NOTHING
					ON CONFLICT ON CONSTRAINT custom_label_action_filter_custom_label_unique DO NOTHING
					RETURNING 1
			) SELECT COUNT(*) INTO _inserted_custom_label_action_add_cnt
				FROM affected_rows;
					
			WITH affected_rows AS (
				INSERT INTO filters.custom_label_action (owner, filter_id, custom_label_id, custom_label_action)
					(SELECT
						_owner,
						_filter_id,
						custom_label_id,
						'remove'::filters.custom_label_actions
					FROM unnest(_remove_custom_label_ids) custom_label_id)
					--ON CONFLICT DO NOTHING
					ON CONFLICT ON CONSTRAINT custom_label_action_filter_custom_label_unique DO NOTHING
					RETURNING 1
			) SELECT COUNT(*) INTO _inserted_custom_label_action_remove_cnt
				FROM affected_rows;
			
		END IF;	
	END IF;
		
	RETURN QUERY
		SELECT fvw.id, fvw.name, fvw.criteria, fvw.postal_labels, fvw.add_custom_label_ids, fvw.remove_custom_label_ids FROM filters.filter_vw fvw
			WHERE fvw.owner = _owner AND fvw.id = _inserted_filter_id OR fvw.id = _filter_id;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

--SELECT * FROM filters.upsert_filter('jdoe@leadict.com', NULL,'Test5', '4567', NULL, NULL, NULL);
