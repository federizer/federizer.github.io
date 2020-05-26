CREATE OR REPLACE FUNCTION email.read_attachment(IN _owner character varying, IN _message_id int8, IN _attachment_id int8)
  RETURNS TABLE(id int8,
                uufid uuid,
                uufcid uuid,
                message_id int8,
                filename character varying,
                destination character varying,
                mimetype character varying,
                encoding character varying,
                size int8) AS
$BODY$
DECLARE
	_id int8;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	-- _message_id is required
	/*IF _message_id IS NULL THEN
		RAISE EXCEPTION '_message_id is required.';
	END IF;*/

	IF _message_id IS NOT NULL THEN
		SELECT m.id FROM email.message m
		WHERE m.id = _message_id AND m.sender_email_address = _owner INTO _id;
		IF _id IS NULL THEN
			SELECT e.message_id FROM email.envelope e
			WHERE e.id = _message_id AND e.recipient_email_address = _owner INTO _id;
			IF _id IS NULL THEN
				_id = 0; -- not found
			END IF;
		END IF;
	END IF;

	RETURN QUERY
		SELECT  f.id,
			f.uufid,
			fc.uufcid,
			COALESCE(u.eid, u.id) AS id,
			f.filename,
			fc.destination,
			f.mimetype,
			f.encoding,
			fc.size
		FROM repository.file f
		LEFT JOIN email.attachment a
		ON a.file_id = f.id
		LEFT JOIN LATERAL (
			SELECT 	c.uufcid,
					c.destination,
					c.size,
					c.version_major,
					c.version_minor,
					c.content
			FROM repository.file_content c
			WHERE c.file_id = f.id
			ORDER BY c.version_major DESC, c.version_minor DESC NULLS LAST
			LIMIT 1
			) fc ON TRUE
			RIGHT JOIN 
			(SELECT 
						m.id AS id,
						NULL AS eid,
						m.sender_email_address AS owner
				FROM email.message m
				WHERE (_id IS NULL OR m.id = _id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender
				UNION
				SELECT 
						e.message_id AS id,
						e.id AS eid,
						e.recipient_email_address AS owner
				FROM email.envelope e
				WHERE (_id IS NULL OR e.message_id = _id) AND (e.recipient_email_address = _owner) AND NOT e.deleted_at_recipient AND e.received_at IS NOT NULL
				) u
			ON u.id = a.message_id
			WHERE _attachment_id IS NULL OR f.id = _attachment_id;	

END;			
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT *
FROM email.read_attachment(
	'jharper@gmail.com',	-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	NULL,	-- put the _message_id parameter value instead of '_message_id' (int8) 999
	NULL	-- put the _attachment_id parameter value instead of '_attachment_id' (int8) 999, NULL
);
*/

CREATE OR REPLACE FUNCTION email.attachment_latest_content_id_from_repository_newly_uploaded_exc(IN _owner character VARYING, IN _message_id int8, IN _attachment_id int8) --long name!!! _exc = _excluded
  RETURNS int8 AS
$BODY$
DECLARE
	_attachment_content_id int8;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	-- _message_id is required
	IF _message_id IS NULL THEN
		RAISE EXCEPTION '_message_id is required.';
	END IF;

	-- _attachment_id is required
	IF _attachment_id IS NULL THEN
		RAISE EXCEPTION '_attachment_id is required.';
	END IF;

	SELECT 	c.id
			FROM repository.file_content c
			RIGHT JOIN email.attachment a
			ON a.file_content_id = c.id AND a.file_id = c.file_id
			WHERE a.message_id <> _message_id AND c.file_id = _attachment_id AND EXISTS (
					SELECT 1
					FROM (
						SELECT
							1							
						FROM email.message m
						WHERE (m.id = a.message_id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender
						UNION
						SELECT
							1				
						FROM email.envelope e			
						WHERE (e.message_id = a.message_id) AND (e.recipient_email_address = _owner) AND NOT e.deleted_at_recipient AND e.received_at IS NOT NULL
						) u
				)
			ORDER BY c.version_major DESC, c.version_minor DESC NULLS LAST
			LIMIT 1 INTO _attachment_content_id;

	RETURN _attachment_content_id;
END;			
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION email.attachment_latest_content_id_newly_uploaded(IN _owner character varying, IN _attachment_id int8)
  RETURNS int8 AS
$BODY$
DECLARE
	_found bool;
	_attachment_content_id int8;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	SELECT 1 FROM email.attachment a
	WHERE a.file_id = _attachment_id INTO _found;

	IF _found THEN
		RAISE EXCEPTION '_attachment_id % is not newly uploaded.', _attachment_id;
	END IF;

	SELECT 	fc.id
		FROM repository.file_content fc
		WHERE fc.file_id = _attachment_id AND fc.owner = _owner
		ORDER BY fc.version_major DESC, fc.version_minor DESC NULLS LAST
		LIMIT 1 INTO _attachment_content_id;

	RETURN _attachment_content_id;
END;			
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION email.read_message_search_query(IN _owner character varying, IN _message_id int8, IN _postal_folders jsonb, IN _postal_labels jsonb, IN _custom_label_labels jsonb, IN _search_query text, IN _limit int4, IN _timeline_id int8)
  RETURNS TABLE(id int8,
                postal_folder postal.postal_folders,
                postal_labels jsonb,
                custom_labels jsonb,
  				--uumid uuid,
  				--uupmid uuid,
  				--uumtid uuid,
  				fwd bool,
				sender jsonb,
                subject text,
                body text,
                envelopes jsonb,
                attachments jsonb,
                tags jsonb,
				timeline_id int8,
				snoozed_at timestamptz,
				received_at timestamptz,
                sent_at timestamptz,
			    search_subject tsvector,
			    search_body tsvector,
                updated_at timestamptz,
                created_at timestamptz) AS
$BODY$
DECLARE
	_sql TEXT := 'SELECT * FROM email.read_message($1, $2, $3, $4, $5, $7, $8)';
	_where TEXT;
BEGIN
	IF _search_query IS NOT NULL THEN
		_where := _search_query;
	   /*_where := concat_ws(' AND '
	       , CASE WHEN state               IS NOT NULL THEN 'state = $2'                  END
	       , CASE WHEN district            IS NOT NULL THEN 'district = $3'               END
	       , CASE WHEN bloodGroup          IS NOT NULL THEN 'bloodgroup = $4'             END
	       , CASE WHEN status              IS NOT NULL THEN 'status = $5'                 END
	       , CASE WHEN approveRejectStatus IS NOT NULL THEN 'approve_reject_status  = $6' END
	       , CASE r.level
	            WHEN 'DISTRICT' THEN 'district = $10 AND state = $11 AND fk_id = $12'
	            WHEN 'UNIT'     THEN 'district = $10 AND state = $11 AND fk_id = $12'
	            WHEN 'STATE'    THEN 'state = $11 AND fk_id = $12'
	            WHEN 'NATIONAL' THEN 'fk_id = $12'
	         END);*/
	
		_sql := _sql || ' WHERE ' || _where;
	END IF;

	RETURN QUERY EXECUTE _sql
   		USING _owner, _message_id, _postal_folders, _postal_labels, _custom_label_labels, _search_query, _limit, _timeline_id;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION email.read_message(IN _owner character varying, IN _message_id int8, IN _postal_folders jsonb, IN _postal_labels jsonb, IN _custom_label_labels jsonb, IN _limit int4, IN _timeline_id int8)
  RETURNS TABLE(id int8,
                postal_folder postal.postal_folders,
                postal_labels jsonb,
                custom_labels jsonb,
  				--uumid uuid,
  				--uupmid uuid,
  				--uumtid uuid,
  				fwd bool,
				sender jsonb,
                subject text,
                body text,
                envelopes jsonb,
                attachments jsonb,
                tags jsonb,
				timeline_id int8,
				snoozed_at timestamptz,
				received_at timestamptz,
                sent_at timestamptz,
			    search_subject tsvector,
			    search_body tsvector,
                updated_at timestamptz,
                created_at timestamptz) AS
$BODY$
DECLARE
	_id int8;
	_postal_folders_arr postal.postal_folders[4];
	_postal_labels_arr postal.postal_labels[8];
	_custom_label_labels_arr text[];
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	IF _message_id IS NOT NULL THEN
		SELECT m.id FROM email.message m
		WHERE m.id = _message_id AND m.sender_email_address = _owner INTO _id;
		IF _id IS NULL THEN
			SELECT e.message_id FROM email.envelope e
			WHERE e.id = _message_id AND e.recipient_email_address = _owner INTO _id;
			IF _id IS NULL THEN
				_id = 0; -- not found
			END IF;
		END IF;
	END IF;

	-- check mailbox.postal_folders type
	_postal_folders_arr = ARRAY(SELECT jsonb_array_elements_text(_postal_folders))::text[4];
	-- check mailbox.postal_labels type
	_postal_labels_arr = ARRAY(SELECT jsonb_array_elements_text(_postal_labels))::text[8];
	-- check custom_label.labels
	_custom_label_labels_arr = ARRAY(SELECT jsonb_array_elements_text(_custom_label_labels))::text[];
	RETURN QUERY
SELECT 
	COALESCE(u.eid, u.id) AS id,
	--u.owner,
	u.postal_folder,
	COALESCE(u.postal_labels, '[]'::jsonb) AS postal_labels,
	COALESCE(u.custom_labels, '[]'::jsonb) AS custom_labels,
	--mvw.uumid,
	--mvw.uupmid,
	--mvw.uumtid,
	mvw.fwd,
	mvw.sender,
	mvw.subject,
	mvw.body,
	evw.envelopes,
	avw.attachments,
	--COALESCE(afn.attachments, '[]'::jsonb) AS attachments,
	COALESCE(tvw.tags, '[]'::jsonb) AS tags,
	u.timeline_id,
	u.snoozed_at,
	u.received_at,
	mvw.sent_at,
    mvw.search_subject,
    mvw.search_body,
	mvw.updated_at,
	mvw.created_at
FROM (
	SELECT 
			m.id AS id,
			NULL AS eid,
			m.sender_timeline_id AS timeline_id,
			m.sender_email_address AS owner,
			mbvw.folder AS postal_folder,
			mbvw.labels AS postal_labels,
			clvw.labels AS custom_labels,
			NULL AS snoozed_at,
			NULL AS received_at
	FROM email.message m
	LEFT JOIN postal.mailbox_vw mbvw
	ON m.id = mbvw.message_id
	LEFT JOIN labels.custom_label_vw clvw
	ON mbvw.id = clvw.mailbox_id
	WHERE (_id IS NULL OR m.id = _id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender AND (_timeline_id IS NULL OR _timeline_id > m.sender_timeline_id)
	UNION
	SELECT 
			e.message_id AS id,
			e.id AS eid,
			e.recipient_timeline_id AS timeline_id,
			e.recipient_email_address AS owner,
			mbvw.folder AS postal_folder,
			mbvw.labels AS postal_labels,
			clvw.labels AS custom_labels,
			e.snoozed_at AS snoozed_at,
			e.received_at AS received_at
	FROM email.envelope e
	LEFT JOIN postal.mailbox_vw mbvw
	ON e.id = mbvw.envelope_id
	LEFT JOIN labels.custom_label_vw clvw
	ON mbvw.id = clvw.mailbox_id
	WHERE (_id IS NULL OR e.message_id = _id) AND (e.recipient_email_address = _owner) AND NOT e.deleted_at_recipient AND e.received_at IS NOT NULL AND (_timeline_id IS NULL OR _timeline_id > e.recipient_timeline_id)
	) u
	LEFT JOIN email.message_vw mvw
	ON mvw.id = u.id
	LEFT JOIN email.envelope_vw evw
	ON evw.message_id = u.id
	LEFT JOIN email.attachment_vw avw
  	ON avw.message_id = u.id
	--LEFT JOIN email.read_attachments(_owner, COALESCE(u.eid, u.id)) afn
  	--ON afn.message_id = COALESCE(u.eid, u.id)
	LEFT JOIN email.tag_vw tvw
  	ON tvw.message_id = u.id
 	WHERE (_postal_folders IS NULL OR u.postal_folder = ANY (_postal_folders_arr) OR (u.postal_folder IS NULL AND jsonb_array_length(_postal_folders) = 0)) AND
		  (_postal_labels IS NULL OR (_postal_labels ?| (ARRAY(select * from jsonb_array_elements_text(u.postal_labels))) OR (_postal_labels = COALESCE(u.postal_labels, '[]'::jsonb)))) AND
		  (_custom_label_labels IS NULL OR (_custom_label_labels ?| (ARRAY(select * from jsonb_array_elements_text(u.custom_labels))) OR (_custom_label_labels = COALESCE(u.custom_labels, '[]'::jsonb))))
 	ORDER BY u.timeline_id DESC
	LIMIT _limit;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT * from email.read_message(
	'jdoe@leadict.com',			-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	1,							-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	NULL,							-- put the _postal_folders parameter value instead of '_postal_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "drafts"]'  -- 'or' between values -- 
	NULL,							-- put the _postal_labels parameter value instead of '_postal_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "unread", "trash"]' -- 'or' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Joe"]' -- 'or' between values --
	NULL,							-- put the _limit parameter value instead of '_limit' (int4) NULL, 20 --
	NULL							-- put the _timeline_id parameter value instead of '_timeline_id' (int8) NULL, 123 --
);
SELECT * from email.read_message(
	'jharper@gmail.com',			-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	NULL,							-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	NULL,							-- put the _postal_folders parameter value instead of '_postal_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "drafts"]'  -- 'or' between values -- 
	NULL,							-- put the _postal_labels parameter value instead of '_postal_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "unread", "trash"]' -- 'or' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Joe"]' -- 'or' between values --
	NULL,							-- put the _limit parameter value instead of '_limit' (int4) NULL, 20 --
	NULL							-- put the _timeline_id parameter value instead of '_timeline_id' (int8) NULL, 123 --
);
*/

CREATE OR REPLACE FUNCTION email.create_message(IN _owner character varying, IN _display_name character varying, IN _message jsonb, IN _parent_message_id int8, IN _fwd boolean)
  RETURNS int8 AS
$BODY$
BEGIN
	RETURN email.upsert_message(_owner, NULL, _display_name, _message, _parent_message_id, _fwd, false); 
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION email.create_and_send_message(IN _owner character varying, IN _display_name character varying, IN _message jsonb, IN _parent_message_id int8, IN _fwd boolean)
  RETURNS int8 AS
$BODY$
BEGIN
	RETURN email.upsert_message(_owner, NULL, _display_name, _message, _parent_message_id, _fwd, true); 
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION email.update_message(IN _owner character varying, IN _message_id int8, IN _display_name character varying, IN _message jsonb)
  RETURNS int8 AS
$BODY$
BEGIN
	RETURN email.upsert_message(_owner, _message_id, _display_name, _message, NULL, NULL, false); 
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION email.update_and_send_message(IN _owner character varying, IN _message_id int8, IN _display_name character varying, IN _message jsonb)
  RETURNS int8 AS
$BODY$
BEGIN
	RETURN email.upsert_message(_owner, _message_id, _display_name, _message, NULL, NULL, true); 
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION email.upsert_message(IN _owner character varying, IN _message_id int8, IN _display_name character varying, IN _message jsonb, IN _parent_message_id int8, IN _fwd bool, IN _send bool)
  RETURNS int8 AS
$BODY$
DECLARE
	_id int8;
	_parent_id int8;
	_ret_id int8 := 0;
	_uupmid uuid;
	_uumtid uuid;
	_attachments jsonb;
	_rec record;
	_found_id int8;
	_attachment_arr int8[] := '{}';
	_attachment_newly_uploaded_arr int8[] := '{}';
	_attachment_sent_or_recieved_arr int8[] := '{}';
	_attachment_in_repository_newly_uploaded_excluded_arr int8[] := '{}';
	_attachment_in_repository_newly_uploaded_included_arr int8[] := '{}';
	_attachment_draft_arr int8[] := '{}';
	_diff_cnt int8;
	_found_cnt int8;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	IF _message_id IS NULL AND _parent_message_id IS NULL AND _fwd = true THEN
		RAISE EXCEPTION 'ambiguous parameter combination _message_id %, _parent_message_id %, _fwd: % ', _message_id, _parent_message_id, _fwd;
	END IF;
	IF _message_id IS NOT NULL AND (_parent_message_id IS NOT NULL OR _fwd = true) THEN
		RAISE EXCEPTION 'ambiguous parameter combination _message_id %, _parent_message_id %, _fwd: % ', _message_id, _parent_message_id, _fwd;
	END IF;
	IF _message_id IS NOT NULL THEN
		SELECT m.id FROM email.message m
		WHERE m.id = _message_id AND m.sender_email_address = _owner INTO _id;
		IF _id IS NULL THEN
			SELECT e.message_id FROM email.envelope e
			WHERE e.id = _message_id AND e.recipient_email_address = _owner INTO _id;
			IF _id IS NULL THEN
				_id = 0; -- not found
				--RAISE EXCEPTION '_message_id: % not found', _message_id;
				RETURN NULL;
			END IF;
		END IF;
	END IF;
	IF _parent_message_id IS NOT NULL THEN
		SELECT m.id FROM email.message m
		WHERE m.id = _parent_message_id AND m.sender_email_address = _owner INTO _parent_id;
		IF _parent_id IS NULL THEN
			SELECT e.message_id FROM email.envelope e
			WHERE e.id = _parent_message_id AND e.recipient_email_address = _owner INTO _parent_id;
			IF _parent_id IS NULL THEN
				_parent_id = 0; -- not found
				--RAISE EXCEPTION '_parent_message_id: % not found', _parent_message_id;
				RETURN NULL;
			END IF;
		END IF;
	END IF;
	IF _id IS NULL THEN
		IF _parent_id IS NOT NULL THEN
			IF _fwd = true THEN
				SELECT uumid FROM email.message
					WHERE id = _parent_id INTO _uupmid;
			ELSE
				SELECT uumid, uumtid FROM email.message
					WHERE id = _parent_id INTO _uupmid, _uumtid;
				IF _uumtid IS NULL THEN
					RAISE NOTICE '_uumtid not found.';
				END IF;
			END IF;
			IF _uupmid IS NULL THEN
				RAISE NOTICE '_uupmid not found.';
			END IF;
		END IF;
		IF _uumtid IS NULL THEN
			_uumtid := public.gen_random_uuid(); 
		END IF;
		INSERT INTO email.message (uupmid,
								 uumtid,
								 fwd, 
								 sender_email_address,
								 sender_display_name,
								 subject,
								 body,
								 sent_at)
			VALUES(_uupmid,
				_uumtid,
				COALESCE(_fwd, false),
				_owner,
				_display_name,
				_message->>'subject',
				_message->>'body',
				CASE WHEN _send = true THEN now() ELSE NULL END) RETURNING id INTO _ret_id;
	ELSEIF _id > 0 THEN
		IF _parent_id IS NOT NULL AND _parent_id = _id THEN
			RAISE EXCEPTION '_parent_id and _id: % cannot be equal.', _parent_id;
		END IF;
		UPDATE email.message
			SET sender_display_name = _display_name,
				subject = _message->>'subject',
				body = _message->>'body',
				sent_at = CASE WHEN _send = true THEN now() ELSE NULL END
			WHERE id = _id AND sender_email_address = _owner AND sent_at IS NULL AND NOT deleted_at_sender RETURNING id INTO _ret_id;
	END IF;
	IF _ret_id > 0 THEN
	--email.attachment-begin------------------
		_attachments = _message->'attachments';
		IF _attachments IS NOT NULL AND jsonb_typeof(_attachments) = 'array' /*AND jsonb_array_length(_attachments) > 0*/ THEN
		
			FOR _rec IN SELECT
				 elm->>'id' AS id
				FROM jsonb_array_elements(_attachments) elm
			LOOP
				IF REGEXP_REPLACE(COALESCE(_rec.id::text, '0'), '[^0-9]*' ,'0')::int8 > 0 THEN
					_attachment_arr := _attachment_arr || _rec.id::int8;

					SELECT f.id FROM
					repository.file f
					LEFT JOIN email.attachment a
					ON f.id = a.file_id
					WHERE f.id = _rec.id::int8 AND f.owner = _owner AND a.message_id IS NULL INTO _found_id;
					IF _found_id > 0 THEN
						_attachment_newly_uploaded_arr := _attachment_newly_uploaded_arr || _found_id::int8;
					END IF;
					
					SELECT f.id FROM
					repository.file f
					LEFT JOIN email.attachment a
					ON f.id = a.file_id
					WHERE f.id = _rec.id::int8 AND EXISTS (
						SELECT 1
							FROM (
								SELECT 1
								FROM email.message m
								WHERE (m.id = a.message_id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender AND m.sent_at IS NOT NULL
								UNION
								SELECT 1
								FROM email.envelope e			
								WHERE (e.message_id = a.message_id) AND (e.recipient_email_address = _owner) AND NOT e.deleted_at_recipient AND e.received_at IS NOT NULL
								) u
					) INTO _found_id;
					IF _found_id > 0 THEN
						_attachment_sent_or_recieved_arr := _attachment_sent_or_recieved_arr || _found_id;
					END IF;
				
					SELECT f.id FROM
					repository.file f
					LEFT JOIN email.attachment a
					ON f.id = a.file_id
					WHERE f.id = _rec.id::int8 AND EXISTS (
						SELECT 1
							FROM (
								SELECT 1
								FROM email.message m
								WHERE (m.id = a.message_id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender
								UNION
								SELECT 1
								FROM email.envelope e			
								WHERE (e.message_id = a.message_id) AND (e.recipient_email_address = _owner) AND NOT e.deleted_at_recipient AND e.received_at IS NOT NULL
								) u
					) INTO _found_id;
					IF _found_id > 0 THEN
						_attachment_in_repository_newly_uploaded_excluded_arr := _attachment_in_repository_newly_uploaded_excluded_arr || _found_id;
					END IF;
				
					SELECT f.id FROM
					repository.file f
					LEFT JOIN email.attachment a
					ON f.id = a.file_id
					WHERE f.id = _rec.id::int8 AND (a.message_id IS NULL OR EXISTS (
						SELECT 1
							FROM (
								SELECT 1
								FROM email.message m
								WHERE (m.id = a.message_id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender
								UNION
								SELECT 1
								FROM email.envelope e			
								WHERE (e.message_id = a.message_id) AND (e.recipient_email_address = _owner) AND NOT e.deleted_at_recipient AND e.received_at IS NOT NULL
								) u
					)) INTO _found_id;
					IF _found_id > 0 THEN
						_attachment_in_repository_newly_uploaded_included_arr := _attachment_in_repository_newly_uploaded_included_arr || _found_id;
					END IF;							
				END IF;			
			END LOOP;
		
			SELECT count(*) FROM (
					SELECT 1
					FROM
					  unnest(_attachment_arr)
					EXCEPT ALL
					SELECT 1
					FROM
					  unnest(_attachment_in_repository_newly_uploaded_included_arr)
				) diff INTO _diff_cnt;
			RAISE NOTICE 'attachment not found in repository: %', _diff_cnt;
			IF _diff_cnt > 0 THEN
				RAISE EXCEPTION 'attachment ids not found'; -- rollback
			END IF;

			FOR _rec IN SELECT id
				FROM
				  unnest(_attachment_in_repository_newly_uploaded_excluded_arr) id
			LOOP
				SELECT count(*)
				FROM email.attachment a
				WHERE a.file_id = _rec.id AND a.message_id = _ret_id INTO _found_cnt;
			
				RAISE NOTICE '_found_cnt: % % %', _rec.id, _ret_id, _found_cnt;

				IF COALESCE(_found_cnt, 0) = 0 THEN
					INSERT INTO email.attachment (owner, message_id, file_id, file_content_id)
						SELECT  _owner,
								_ret_id,
								id,
								email.attachment_latest_content_id_from_repository_newly_uploaded_exc(_owner, _ret_id, id)
						FROM unnest(_attachment_in_repository_newly_uploaded_excluded_arr) id;			
				END IF;
			END LOOP;
					
			INSERT INTO email.attachment (owner, message_id, file_id, file_content_id)
				SELECT  _owner,
						_ret_id,
						id,
						email.attachment_latest_content_id_newly_uploaded(_owner, id)
				FROM unnest(_attachment_newly_uploaded_arr) id;

			IF _id IS NOT NULL THEN
				SELECT array(
					SELECT f.id FROM
					repository.file f
					LEFT JOIN email.attachment a
					ON f.id = a.file_id
					WHERE a.message_id = _ret_id AND EXISTS (
						SELECT 1
							FROM email.message m
							WHERE (m.id = a.message_id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender AND m.sent_at IS NULL
					)		
				) INTO _attachment_draft_arr;

				--RAISE EXCEPTION 'attachments %, %', _attachment_arr, _attachment_draft_arr; -- rollback
				
				FOR _rec IN SELECT id FROM (
							SELECT id
							FROM
							  unnest(_attachment_draft_arr) id
							EXCEPT ALL
							SELECT id
							FROM
							  unnest(_attachment_arr) id
						) diff
				LOOP
					SELECT count(*)
					FROM email.attachment a
					WHERE a.file_id = _rec.id AND a.message_id <> _ret_id INTO _found_cnt;

					DELETE FROM email.attachment a
					WHERE a.file_id = _rec.id AND a.message_id = _ret_id AND a.owner = _owner;

					IF COALESCE(_found_cnt, 0) = 0 THEN
						DELETE FROM repository.file f
						WHERE f.id = _rec.id AND f.owner = _owner;
					END IF;
				END LOOP;
			END IF;								
			
		END IF;
--email.attachment-end------------------
--delete-all-from-envelope-and-mailbox-begin------------------
		IF _id IS NOT NULL THEN
			-- delete from email.envelope also deletes cascade from postal.mailbox
			--DELETE FROM postal.mailbox
			--	WHERE message_id = _ret_id AND envelope_id IS NOT NULL;
			DELETE FROM email.envelope
				WHERE message_id = _ret_id;
		END IF;
--delete-all-from-envelope-and-mailbox-end------------------
--email.envelopes/postal.mailbox-recipient-begin--------------------			
		INSERT INTO email.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name,
									 received_at)
			SELECT
				_ret_id,
				'to' AS type,
				to_recipient->>'email_address' AS email_address,
				to_recipient->>'display_name' AS display_name,
				CASE WHEN _send = true THEN now() ELSE NULL END
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, to}') to_recipient;
		IF _send = true THEN
			INSERT INTO postal.mailbox (owner, envelope_id,	folder, unread)
				SELECT
					to_recipient.recipient_email_address,
					to_recipient.id,
					'inbox'::postal.postal_folders,
					true
				FROM email.envelope to_recipient
				WHERE to_recipient.message_id = _ret_id AND to_recipient.type = 'to'::email.envelope_type;
		END IF;
		INSERT INTO email.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name,
									 received_at)
			SELECT
				_ret_id,
				'cc' AS type,
				cc_recipient->>'email_address' AS email_address,
				cc_recipient->>'display_name' AS display_name,
				CASE WHEN _send = true THEN now() ELSE NULL END
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, cc}') cc_recipient;								 
		IF _send = true THEN
			INSERT INTO postal.mailbox (owner, envelope_id,	folder, unread)
				SELECT
					cc_recipient.recipient_email_address,
					cc_recipient.id,
					'inbox'::postal.postal_folders,
					true
				FROM email.envelope cc_recipient
				WHERE cc_recipient.message_id = _ret_id AND cc_recipient.type = 'cc'::email.envelope_type;
		END IF;
		INSERT INTO email.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name,
									 received_at)
			SELECT
				_ret_id,
				'bcc' AS type,
				bcc_recipient->>'email_address' AS email_address,
				bcc_recipient->>'display_name' AS display_name,
				CASE WHEN _send = true THEN now() ELSE NULL END
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, bcc}') bcc_recipient;								 
		IF _send = true THEN
			INSERT INTO postal.mailbox (owner, envelope_id,	folder, unread)
				SELECT
					bcc_recipient.recipient_email_address,
					bcc_recipient.id,
					'inbox'::postal.postal_folders,
					true
				FROM email.envelope bcc_recipient
				WHERE bcc_recipient.message_id = _ret_id AND bcc_recipient.type = 'bcc'::email.envelope_type;
		END IF;
--email.envelopes/postal.mailbox-recipient-end--------------------			
--email.tag-begin------------------	
		IF _id IS NOT NULL THEN
			DELETE FROM email.tag
				WHERE message_id = _ret_id;
		END IF;
		INSERT INTO email.tag (message_id,
								 type,
								 name,
								 value)
			SELECT
				_ret_id,
				(tags->>'type')::int2 AS type,
				tags->>'name' AS name,
				tags->>'value' AS value
			FROM jsonb_array_elements(_message::jsonb->'tags') tags;
--email.tag-end--------------------			
--postal.mailbox-sender-begin--------------------			
		IF _send = true THEN
			IF _id IS NULL THEN
				INSERT INTO postal.mailbox (owner,	message_id,	folder)
					VALUES(_owner, _ret_id,	'sent'::postal.postal_folders);
			ELSE
				UPDATE postal.mailbox
					SET folder = 'sent'::postal.postal_folders
					WHERE message_id = _ret_id AND owner = _owner;			
			END IF;
		ELSE
			IF _id IS NULL THEN
				INSERT INTO postal.mailbox (owner,	message_id,	folder)
					VALUES(_owner, _ret_id,	'drafts'::postal.postal_folders);
			END IF;
		END IF;
--postal.mailbox-sender-end--------------------			
		RETURN _ret_id;
	ELSE
		RETURN NULL;
	END IF;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

--SELECT email.upsert_message('jdoe@leadict.com', NULL, 'John Doe', '{"body":"A message to delete X1","subject":"To delete X1","envelopes":{"to":[{"display_name":"Peter Salon","email_address":"peter.salon@gmail.com"}],"cc":[{"display_name":"Joe Harper","email_address":"jharper@gmail.com"}],"bcc":[{"display_name":"Filip Figuli","email_address":"ffiguli@leadict.com"},{"display_name":"Rastislav Filip","email_address":"rastislav.filip@gmail.com"}]},"tags":[{"type":0,"name":"invoice","value":"164/11"},{"type":1,"name":"number","value":1234}]}', NULL, 'send');
--SELECT email.upsert_message('jdoe@leadict.com', 3, 'John Doe', '{"body":"A message to delete X1","subject":"To delete X1","envelopes":{"to":[{"display_name":"Peter Salon","email_address":"peter.salon@gmail.com"}],"cc":[{"display_name":"Joe Harper","email_address":"jharper@gmail.com"}],"bcc":[{"display_name":"Filip Figuli","email_address":"ffiguli@leadict.com"},{"display_name":"Rastislav Filip","email_address":"rastislav.filip@gmail.com"}]},"tags":[{"type":0,"name":"invoice","value":"164/11"},{"type":1,"name":"number","value":1234}]}', NULL, '{"action":"send"}'::jsonb);
--SELECT email.upsert_message('jdoe@leadict.com', 3, 'John Doe', '{"body":"A message to delete X1","subject":"To delete X1","envelopes":{"to":[{"display_name":"Peter Salon","email_address":"peter.salon@gmail.com"}],"cc":[{"display_name":"Joe Harper","email_address":"jharper@gmail.com"}],"bcc":[{"display_name":"Filip Figuli","email_address":"ffiguli@leadict.com"},{"display_name":"Rastislav Filip","email_address":"rastislav.filip@gmail.com"}]},"tags":[{"type":0,"name":"invoice","value":"164/11"},{"type":1,"name":"number","value":1234}]}', NULL, '{"action":"send"}');
/*SELECT email.update_message('jharper@gmail.com', 14, 'Joe Harper',
'{
	"body": "Howdy...",
	"subject": "Howdy!",
	"envelopes": {
		"to": [{
			"display_name": "Joe Harper",
			"email_address": "jharper@gmail.com"
		}, {
			"display_name": "John Doe",
			"email_address": "jdoe@leadict.com"
		}]
	},
	"attachments": [{
		"id": 4,
		"size": 14,
		"uuaid": "61e9eff8-22bf-43a0-a53d-921b2fc4c283",
		"encoding": "7bit",
		"filename": "Hello World.txt",
		"mimetype": "text/plain",
		"destination": "./attachments/"
	}]
}'::jsonb);*/

/*
SELECT * from email.read_message(
	'jharper@gmail.com',			-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	NULL,							-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	NULL,							-- put the _postal_folders parameter value instead of '_postal_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "drafts"]'  -- 'or' between values -- 
	NULL,							-- put the _postal_labels parameter value instead of '_postal_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "unread", "trash"]' -- 'or' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Joe"]' -- 'or' between values --
	NULL,							-- put the _limit parameter value instead of '_limit' (int4) NULL, 20 --
	NULL							-- put the _timeline_id parameter value instead of '_timeline_id' (int8) NULL, 123 --
)
*/

CREATE OR REPLACE FUNCTION email.delete_message(IN _owner character VARYING, IN _message_id int8)
  RETURNS int8 AS
$BODY$
DECLARE
	_id int8;
	_attachment_draft_arr int8[] := '{}';
	_rec record;
	_found_cnt int8;
	_drafts_row_cnt int8 := 0;
	_sent_row_cnt int8 := 0;
	_envelope_row_cnt int8 := 0; -- inbox
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	IF _message_id IS NOT NULL THEN
		SELECT m.id FROM email.message m
		WHERE m.id = _message_id AND m.sender_email_address = _owner INTO _id;
		IF _id IS NULL THEN
			SELECT e.message_id FROM email.envelope e
			WHERE e.id = _message_id AND e.recipient_email_address = _owner INTO _id;
			IF _id IS NULL THEN
				_id = 0; -- not found
				--RETURN NULL;
				RETURN 0;
			END IF;
		END IF;
	END IF;
	IF _id IS NOT NULL THEN
		-- delete attachment/content
		SELECT array(
			SELECT f.id FROM
			repository.file f
			LEFT JOIN email.attachment a
			ON f.id = a.file_id
			WHERE a.message_id = _message_id AND EXISTS (
				SELECT 1
					FROM email.message m
					WHERE (m.id = a.message_id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender AND m.sent_at IS NULL
			)		
		) INTO _attachment_draft_arr;

		FOR _rec IN SELECT id
					FROM
					  unnest(_attachment_draft_arr) id
		LOOP
			SELECT count(*)
			FROM email.attachment a
			WHERE a.file_id = _rec.id AND a.message_id <> _message_id INTO _found_cnt;

			DELETE FROM email.attachment a
			WHERE a.file_id = _rec.id AND a.message_id = _message_id AND a.owner = _owner;

			IF COALESCE(_found_cnt, 0) = 0 THEN
				DELETE FROM repository.file f
				WHERE f.id = _rec.id AND f.owner = _owner;
			END IF;
		END LOOP;
		-- delete drafts
		WITH affected_rows AS (
			DELETE FROM email.message -- cascade
				WHERE id = _id AND sender_email_address = _owner AND sent_at IS NULL RETURNING 1
		) SELECT COUNT(*) INTO _drafts_row_cnt
		  FROM affected_rows;
		-- delete sent
		WITH affected_rows AS (
			UPDATE email.message
				SET deleted_at_sender = true
				WHERE id = _id AND sender_email_address = _owner AND sent_at IS NOT NULL AND NOT deleted_at_sender RETURNING 1
		) SELECT COUNT(*) INTO _sent_row_cnt
		  FROM affected_rows;		
		-- delete inbox
		WITH affected_rows AS (
			UPDATE email.envelope e
						SET deleted_at_recipient = true
					WHERE EXISTS (
				  		SELECT 1 FROM email.message m WHERE m.id = _id AND m.sent_at IS NOT NULL
				) AND e.message_id = _id AND e.recipient_email_address = _owner AND NOT e.deleted_at_recipient RETURNING 1
			) SELECT COUNT(*) INTO _envelope_row_cnt
		  FROM affected_rows;	
	END IF;
	RETURN _drafts_row_cnt + _sent_row_cnt + _envelope_row_cnt;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

--SELECT email.delete_message('jdoe@leadict.com', NULL);
--SELECT email.delete_message('jdoe@leadict.com', 1);

CREATE OR REPLACE FUNCTION email.modify_message_list_labels(IN _owner character VARYING, IN _message_ids int8[], IN _postal_labels jsonb, IN _custom_label_ids int8[])
  RETURNS int8 AS
$BODY$
DECLARE
	_message_id int8;
	_msg_id int8;
	_env_id int8;
	_custom_label_id int8;
	_mailbox_id int8;
	_labels_updated boolean;
	_updated_cnt int8 = 0;
	_postal_labels_cnt int8 := 0;
	_custom_labels_cnt int8 := 0;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	FOREACH _message_id IN ARRAY _message_ids
	LOOP 
	    _msg_id = NULL;
	    _env_id = NULL;
		IF _message_id IS NOT NULL THEN
			SELECT m.id FROM email.message m
			WHERE m.id = _message_id AND m.sender_email_address = _owner INTO _msg_id;
			IF _msg_id IS NULL THEN
				SELECT id FROM email.envelope e
				WHERE e.id = _message_id AND e.recipient_email_address = _owner INTO _env_id;
			END IF;
		END IF;
		IF _msg_id > 0 OR _env_id > 0 THEN
		    RAISE NOTICE '% %', _msg_id, _env_id;
		   
		   	_labels_updated = false;
	   		WITH affected_rows AS (
				UPDATE postal.mailbox mb
					SET done = CASE WHEN (_postal_labels->>'done') IS NOT NULL THEN (_postal_labels->>'done')::boolean ELSE done END,
						archived = CASE WHEN (_postal_labels->>'archived') IS NOT NULL THEN (_postal_labels->>'archived')::boolean ELSE archived END,
						starred = CASE WHEN (_postal_labels->>'starred') IS NOT NULL THEN (_postal_labels->>'starred')::boolean ELSE starred END,
						important = CASE WHEN (_postal_labels->>'important') IS NOT NULL THEN (_postal_labels->>'important')::boolean ELSE important END,
						chats = CASE WHEN (_postal_labels->>'chats') IS NOT NULL THEN (_postal_labels->>'chats')::boolean ELSE chats END,
						spam = CASE WHEN (_postal_labels->>'spam') IS NOT NULL THEN (_postal_labels->>'spam')::boolean ELSE spam END,
						unread = CASE WHEN (_postal_labels->>'unread') IS NOT NULL THEN (_postal_labels->>'unread')::boolean ELSE unread END,
						trash = CASE WHEN (_postal_labels->>'trash') IS NOT NULL THEN (_postal_labels->>'trash')::boolean ELSE trash END
					WHERE (mb.message_id = _msg_id OR mb.envelope_id = _env_id) AND mb."owner" = _owner RETURNING 1
			) SELECT COUNT(*) INTO _postal_labels_cnt
				FROM affected_rows;
			IF _postal_labels_cnt > 0 THEN
			    --RAISE NOTICE '_postal_labels_cnt: %', _postal_labels_cnt;
				_labels_updated = true;
			END IF;
			
			_mailbox_id = NULL;
			SELECT id FROM postal.mailbox mb
			WHERE (mb.message_id = _msg_id OR mb.envelope_id = _env_id) AND mb."owner" = _owner into _mailbox_id;
			IF _mailbox_id IS NOT NULL THEN
				DELETE FROM labels.has h
				WHERE h.mailbox_id = _mailbox_id AND h.owner = _owner;
				FOREACH _custom_label_id IN ARRAY _custom_label_ids
				LOOP
					WITH affected_rows AS (
						INSERT INTO labels.has (owner, mailbox_id,	custom_label_id)
							SELECT
								_owner,
								_mailbox_id,
								cl.id
							FROM labels.custom_label cl
							WHERE cl.id = _custom_label_id AND cl."owner" = _owner RETURNING 1			
					) SELECT COUNT(*) INTO _custom_labels_cnt
						FROM affected_rows;
					IF _custom_labels_cnt > 0 THEN
					    RAISE NOTICE '_custom_labels_cnt: %', _custom_labels_cnt;
						_labels_updated = true;
					END IF;
				END LOOP;
			END IF;
			
			IF _labels_updated THEN
				_updated_cnt = _updated_cnt + 1;
			END IF;
		END IF;
	END LOOP;
	RETURN _updated_cnt;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

--SELECT email.modify_message_list_labels('jdoe@leadict.com', '{10, 13, 17, 41, 42, 43, 44}', '{"done": false, "archived": true}'::jsonb, '{1, 2, 3, 4}');

