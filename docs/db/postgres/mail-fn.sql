CREATE OR REPLACE FUNCTION mail.read_envelopes(IN _owner character varying, IN _message_id int8)
  RETURNS TABLE(message_id int8,
                envelopes jsonb,
                received_at timestamptz,
                snoozed_at timestamptz,                
                recipient_timeline_id int8) AS
$BODY$
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	RETURN QUERY
		SELECT  e1.message_id,
				e1.envelopes,
				e2.received_at,
				e2.snoozed_at,
				e2.recipient_timeline_id
				FROM mail.envelope_vw e1
		LEFT JOIN mail.envelope e2
		ON e1.message_id = e2.message_id AND recipient_email_address = _owner
		WHERE (_message_id IS NULL OR e1.message_id = _message_id);
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION mail.read_messages(IN _owner character varying, IN _message_id int8, IN _system_label_folders jsonb, IN _system_label_labels jsonb, IN _custom_label_labels jsonb, IN _limit int4, IN _timeline_id int8)
  RETURNS TABLE(id int8,
				sender jsonb,
                subject text,
                body text,
                envelopes jsonb,
                system_folder labels.system_folders,
                system_labels jsonb,
                custom_labels jsonb,
                attachments jsonb,
                tags jsonb,
                --sender_timeline_id int8,
				--recipient_timeline_id int8,
				timeline_id int8,
				snoozed_at timestamptz,
				received_at timestamptz,
                sent_at timestamptz,
                updated_at timestamptz,
                created_at timestamptz) AS
$BODY$
DECLARE
	_system_label_folders_arr labels.system_folders[4];
	_system_label_labels_arr labels.system_labels[8];
	_custom_label_labels_arr text[];
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	-- check system_label.folders type
	_system_label_folders_arr = ARRAY(SELECT jsonb_array_elements_text(_system_label_folders))::text[4];
	-- check system_label.labels type
	_system_label_labels_arr = ARRAY(SELECT jsonb_array_elements_text(_system_label_labels))::text[8];
	-- check custom_label.labels
	_custom_label_labels_arr = ARRAY(SELECT jsonb_array_elements_text(_custom_label_labels))::text[];
	RETURN QUERY
	SELECT --DISTINCT ON (timeline_id)
			mu.id,
			mu.sender,
			mu.subject,
			mu.body,
			e.envelopes,
			sl.folder AS system_folder,
			sl.labels AS system_labels,
			cl.labels AS custom_labels,
			a.attachments,
			t.tags,
			--mu.sender_timeline_id,
			--e.recipient_timeline_id,
			GREATEST(e.recipient_timeline_id, mu.sender_timeline_id) AS timeline_id,
			e.snoozed_at,
			e.received_at,
			mu.sent_at,
			mu.updated_at,
			mu.created_at
	FROM (SELECT m.id,
			m.sender,
			m.subject,
			m.body,
			m.sender_timeline_id,
			m.sent_at,
			m.created_at,
			m.updated_at
	FROM (SELECT mail.message.id,  mail.message.sender_email_address AS sender_email_address, mail.message.deleted_at_sender AS deleted_at_sender, NULL AS deleted_at_recipient FROM mail.message WHERE mail.message.sender_email_address = _owner
	UNION SELECT mail.envelope.message_id, NULL, NULL, mail.envelope.deleted_at_recipient FROM mail.envelope WHERE mail.envelope.recipient_email_address = _owner) u
	LEFT JOIN mail.message_vw m
	ON u.id = m.id
	WHERE ((u.sender_email_address = _owner AND NOT u.deleted_at_sender) OR (m.sent_at IS NOT NULL AND NOT u.deleted_at_recipient))) mu
	LEFT JOIN mail.read_envelopes(_owner, _message_id) e
  	ON mu.id = e.message_id
	LEFT JOIN mail.attachment_vw a
  	ON mu.id = a.message_id
	LEFT JOIN mail.tag_vw t
  	ON mu.id = t.message_id
	LEFT JOIN labels.system_label_vw sl
  	ON mu.id = sl.message_id AND sl.owner = _owner
	LEFT JOIN labels.custom_label_vw cl
  	ON mu.id = cl.message_id AND cl.owner = _owner
	WHERE (_timeline_id IS NULL OR _timeline_id > GREATEST(e.recipient_timeline_id, mu.sender_timeline_id)) AND
		  (_message_id IS NULL OR mu.id = _message_id) AND
		  (_system_label_folders IS NULL OR sl.folder = ANY (_system_label_folders_arr) OR (sl.folder IS NULL AND jsonb_array_length(_system_label_folders) = 0)) AND
		  (_system_label_labels IS NULL OR (_system_label_labels ?| (ARRAY(select * from jsonb_array_elements_text(sl.labels))) OR (_system_label_labels = COALESCE(sl.labels, '[]'::jsonb)))) AND
		  (_custom_label_labels IS NULL OR (_custom_label_labels ?| (ARRAY(select * from jsonb_array_elements_text(cl.labels))) OR (_custom_label_labels = COALESCE(cl.labels, '[]'::jsonb))))
	ORDER BY GREATEST(e.recipient_timeline_id, mu.sender_timeline_id) DESC, LEAST(e.recipient_timeline_id, mu.sender_timeline_id) DESC
	LIMIT _limit;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT * from mail.read_messages(
	'izboran@gmail.com',			-- put the _owner parameter value instead of '_owner' (varchar) izboran@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	NULL,							-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	NULL,							-- put the _system_label_folders parameter value instead of '_system_label_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "draft"]'  -- 'or' between values -- 
	NULL,							-- put the _system_label_labels parameter value instead of '_system_label_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "unread", "trash"]' -- 'or' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Igor"]' -- 'or' between values --
	NULL,							-- put the _limit parameter value instead of '_limit' (int4) NULL, 20 --
	NULL							-- put the _timeline_id parameter value instead of '_timeline_id' (int8) NULL, 123 --
)
*/

CREATE OR REPLACE FUNCTION mail.read_attachment(IN _owner character varying, IN _message_id int8, IN _name character varying)
  RETURNS TABLE(id int8,
                destination character varying,
                filename character varying,
                mimetype character varying,
                encoding character varying,
                size int8) AS
$BODY$
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	RETURN QUERY
		SELECT  m.id,
				a.destination,
				a.filename,
				a.mimetype,
				a.encoding,
				a.size
				FROM mail.read_messages(_owner, _message_id, NULL, NULL, NULL, NULL, NULL) m
				LEFT JOIN mail.attachment a
				ON m.id = a.message_id AND a.name = _name;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT *  FROM mail.read_attachment(
	'izboran@gmail.com',					-- put the _owner parameter value instead of '_owner' (varchar) izboran@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	1,										-- put the _message_id parameter value instead of '_message_id' (int8) 123
	'70d2d183-49da-4400-8318-de0275167a80' 	-- put the _name parameter value instead of '_name' (varchar) 70d2d183-49da-4400-8318-de0275167a80
);
*/

CREATE OR REPLACE FUNCTION mail.delete_attachment(IN _owner character varying, IN _message_id int8, IN _name character varying)
  RETURNS int8 AS
$BODY$
DECLARE
	_row_cnt int8 := 0;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	WITH affected_rows AS (
		DELETE FROM mail.attachment a WHERE EXISTS (
	  		SELECT 1 FROM mail.message m WHERE a.message_id = m.id AND m.sender_email_address = _owner AND m.sent_at IS NULL AND NOT m.deleted_at_sender
		) AND a.message_id = _message_id AND a.name = _name RETURNING 1
	) SELECT COUNT(*) INTO _row_cnt
	  FROM affected_rows;
	/*WITH affected_rows AS (
	        DELETE FROM mail.attachment
	        USING mail.attachment AS a
			INNER JOIN mail.message AS m
			ON a.message_id = m.id AND m.sender_email_address = _owner AND m.sent_at IS NULL AND NOT m.deleted_at_sender
			WHERE mail.attachment.id = a.id AND a.message_id = _message_id AND a.name = _name RETURNING m.id
	       )
	  SELECT COUNT(*) INTO _row_cnt
	  		FROM affected_rows;*/
 	RETURN _row_cnt;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT mail.delete_attachment(
	'izboran@gmail.com',					-- put the _owner parameter value instead of '_owner' (varchar) izboran@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	4,										-- put the _message_id parameter value instead of '_message_id' (int8) 123
	'74aa8f05-f2a2-4da4-981d-e9728f7a4fc1' 	-- put the _name parameter value instead of '_name' (varchar) 70d2d183-49da-4400-8318-de0275167a80
);
*/

CREATE OR REPLACE FUNCTION mail.create_attachment(IN _owner character varying, IN _message_id int8, IN _attachments jsonb)
  RETURNS jsonb AS
$BODY$
DECLARE
	_row_cnt int8 := 0;
	_jsonb_array jsonb;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	WITH affected_rows AS (
		INSERT INTO mail.attachment (message_id,
									 destination,
									 filename,
									 name,
									 mimetype,
									 encoding,
									 size
									 )
			SELECT
 				_message_id,
				elm->>'destination' AS destination,
				elm->>'filename' AS filename,
				elm->>'name' AS name,
				elm->>'mimetype' AS mimetype,
				elm->>'encoding' AS encoding,
				(elm->>'size')::int8 AS size
			FROM jsonb_array_elements(_attachments)	elm								 
			WHERE EXISTS (	
	  			SELECT 1 FROM mail.message m WHERE m.id = _message_id AND m.sender_email_address = _owner AND m.sent_at IS NULL AND NOT m.deleted_at_sender
	  		) RETURNING 1
	) SELECT COUNT(*) INTO _row_cnt
	  FROM affected_rows;
	IF _row_cnt > 0 THEN
		SELECT array_to_json(array_agg(s)) FROM (SELECT 
				elm->>'destination' AS destination,
				elm->>'filename' AS filename,
				elm->>'name' AS name,
				elm->>'mimetype' AS mimetype,
				elm->>'encoding' AS encoding,
				(elm->>'size')::int8 AS size
			FROM jsonb_array_elements(_attachments)	elm) s INTO _jsonb_array;
		RETURN _jsonb_array;
	ELSE
		RETURN NULL;
	END IF;
 	--RETURN /*_row_cnt, */_attachments;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT mail.create_attachment(
	'izboran@gmail.com',					-- put the _owner parameter value instead of '_owner' (varchar) izboran@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	14,										-- put the _message_id parameter value instead of '_message_id' (int8) 123
	'[
	  {
	    "filename": "Hello World.txt",
	    "encoding": "7bit",
	    "mimetype": "text/plain",
	    "destination": "./attachments/",
	    "name": "98174f15-ba7a-4832-8cb8-9d5a3a88f8d1",
	    "size": 14
	  }
	]' 	-- put the _name parameter value instead of '_attachments' (jsonb)
);
*/

CREATE OR REPLACE FUNCTION mail.upsert_message(IN _id int8, IN _owner character varying, IN _display_name character varying, IN _message jsonb, _send bool)
  RETURNS int8 AS
$BODY$
DECLARE
	_ret_id int8 := 0;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	IF _id IS NULL THEN
		INSERT INTO mail.message (sender_email_address,
								 sender_display_name,
								 subject,
								 body,
								 sent_at)
			VALUES(_owner,
				_display_name,
				_message->>'subject',
				_message->>'body',
				CASE WHEN _send THEN now() ELSE NULL END) RETURNING id	INTO _ret_id;
	ELSE
		UPDATE mail.message
			SET sender_display_name = _display_name,
				subject = _message->>'subject',
				body = _message->>'body',
				sent_at = CASE WHEN _send THEN now() ELSE NULL END
			WHERE id = _id AND sender_email_address = _owner AND sent_at IS NULL AND NOT deleted_at_sender RETURNING id INTO _ret_id;
	END IF;
	IF _ret_id > 0 THEN
--mail.envelopes/mail.system_label-recipient-begin--------------------			
		IF _id IS NOT NULL THEN
			DELETE FROM mail.envelope
				WHERE message_id = _id;
			DELETE FROM labels.system_label
				WHERE message_id = _id;
		END IF;
		INSERT INTO mail.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name)
			SELECT
				_ret_id,
				'to' AS type,
				to_recipient->>'email_address' AS email_address,
				to_recipient->>'display_name' AS display_name
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, to}') to_recipient;
		IF _send THEN
			INSERT INTO labels.system_label (owner,	message_id,	folder)
				SELECT
					to_recipient->>'email_address',
					_ret_id,
					'inbox'
				FROM jsonb_array_elements(_message::jsonb#>'{envelopes, to}') to_recipient;
		END IF;
		INSERT INTO mail.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name)
			SELECT
				_ret_id,
				'cc' AS type,
				cc_recipient->>'email_address' AS email_address,
				cc_recipient->>'display_name' AS display_name
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, cc}') cc_recipient;								 
		IF _send THEN
			INSERT INTO labels.system_label (owner,	message_id,	folder)
				SELECT
					cc_recipient->>'email_address',
					_ret_id,
					'inbox'
				FROM jsonb_array_elements(_message::jsonb#>'{envelopes, cc}') cc_recipient;
		END IF;
		INSERT INTO mail.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name)
			SELECT
				_ret_id,
				'bcc' AS type,
				bcc_recipient->>'email_address' AS email_address,
				bcc_recipient->>'display_name' AS display_name
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, bcc}') bcc_recipient;								 
		IF _send THEN
			INSERT INTO labels.system_label (owner,	message_id,	folder)
				SELECT
					bcc_recipient->>'email_address',
					_ret_id,
					'inbox'
				FROM jsonb_array_elements(_message::jsonb#>'{envelopes, bcc}') bcc_recipient;
		END IF;
--mail.envelopes/mail.system_label-recipient-end--------------------			
--mail.tag-begin------------------	
		IF _id IS NOT NULL THEN
			DELETE FROM mail.tag
				WHERE message_id = _id;
		END IF;
		INSERT INTO mail.tag (message_id,
								 type,
								 name,
								 value)
			SELECT
				_ret_id,
				(tags->>'type')::int2 AS type,
				tags->>'name' AS name,
				tags->>'value' AS value
			FROM jsonb_array_elements(_message::jsonb->'tags') tags;
--mail.tag-end--------------------			
--mail.system_label-sender-begin--------------------			
		IF _send THEN
			INSERT INTO labels.system_label (owner,	message_id,	folder)
				VALUES(_owner, _ret_id,	'sent');
		ELSE/*IF _id IS NULL THEN*/
			INSERT INTO labels.system_label (owner,	message_id,	folder)
				VALUES(_owner, _ret_id,	'draft');
		END IF;
--mail.system_label-sender-end--------------------			
		RETURN _ret_id;
	ELSE
		RETURN NULL;
	END IF;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

--SELECT mail.upsert_message(NULL, 'izboran@gmail.com', 'Igor Zboran', '{"body":"A message to delete X1","subject":"To delete X1","envelopes":{"to":[{"display_name":"Peter Salon","email_address":"peter.salon@gmail.com"}],"cc":[{"display_name":"Igor Zboran","email_address":"izboran@gmail.com"}],"bcc":[{"display_name":"Filip Figuli","email_address":"ffiguli@leadict.com"},{"display_name":"Rastislav Filip","email_address":"rastislav.filip@gmail.com"}]},"tags":[{"type":0,"name":"invoice","value":"164/11"},{"type":1,"name":"number","value":1234}]}');


CREATE OR REPLACE FUNCTION mail.delete_message(IN _id int8, IN _owner character varying)
  RETURNS int8 AS
$BODY$
DECLARE
	_ret_id int8 := 0;
	_drafts_row_cnt int8 := 0;
	_sent_row_cnt int8 := 0;
	_envelope_row_cnt int8 := 0; -- inbox
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	IF _id IS NOT NULL THEN
		-- delete drafts
		WITH affected_rows AS (
			DELETE FROM mail.message -- cascade
				WHERE id = _id AND sender_email_address = _owner AND sent_at IS NULL RETURNING 1
		) SELECT COUNT(*) INTO _drafts_row_cnt
		  FROM affected_rows;		
		-- delete sent
		WITH affected_rows AS (
			UPDATE mail.message
				SET deleted_at_sender = true
				WHERE id = _id AND sender_email_address = _owner AND sent_at IS NOT NULL AND NOT deleted_at_sender RETURNING 1
		) SELECT COUNT(*) INTO _sent_row_cnt
		  FROM affected_rows;		
		-- delete inbox
		WITH affected_rows AS (
			UPDATE mail.envelope e
						SET deleted_at_recipient = true
					WHERE EXISTS (
				  		SELECT 1 FROM mail.message m WHERE m.id = _id AND m.sent_at IS NOT NULL
				) AND e.message_id = _id AND e.recipient_email_address = _owner AND NOT e.deleted_at_recipient RETURNING 1
			) SELECT COUNT(*) INTO _envelope_row_cnt
		  FROM affected_rows;	
	END IF;
	RETURN _drafts_row_cnt + _sent_row_cnt + _envelope_row_cnt;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

--SELECT mail.delete_message(NULL, 'izboran@gmail.com');
