CREATE OR REPLACE FUNCTION mail.read_messages(IN _owner character varying, IN _message_id int8, IN _mailbox_folders jsonb, IN _mailbox_labels jsonb, IN _custom_label_labels jsonb, IN _limit int4, IN _timeline_id int8)
  RETURNS TABLE(id int8,
                mailbox_folder postal.mailbox_folders,
                mailbox_labels jsonb,
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
                updated_at timestamptz,
                created_at timestamptz) AS
$BODY$
DECLARE
	_mailbox_folders_arr postal.mailbox_folders[4];
	_mailbox_labels_arr postal.mailbox_labels[8];
	_custom_label_labels_arr text[];
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	-- check mailbox.folders type
	_mailbox_folders_arr = ARRAY(SELECT jsonb_array_elements_text(_mailbox_folders))::text[4];
	-- check mailbox.labels type
	_mailbox_labels_arr = ARRAY(SELECT jsonb_array_elements_text(_mailbox_labels))::text[8];
	-- check custom_label.labels
	_custom_label_labels_arr = ARRAY(SELECT jsonb_array_elements_text(_custom_label_labels))::text[];
	RETURN QUERY
SELECT 
	u.id,
	--u.owner,
	u.mailbox_folder,
	u.mailbox_labels,
	u.custom_labels,
	--mvw.uumid,
	--mvw.uupmid,
	--mvw.uumtid,
	mvw.fwd,
	mvw.sender,
	mvw.subject,
	mvw.body,
	evw.envelopes,
	avw.attachments,
	tvw.tags,
	u.timeline_id,
	u.snoozed_at,
	u.received_at,
	mvw.sent_at,
	mvw.updated_at,
	mvw.created_at
FROM (
	SELECT 
			m.id AS id,
			m.sender_timeline_id AS timeline_id,
			m.sender_email_address AS owner,
			mbvw.folder AS mailbox_folder,
			mbvw.labels AS mailbox_labels,
			clvw.labels AS custom_labels,
			NULL AS snoozed_at,
			NULL AS received_at
	FROM mail.message m
	LEFT JOIN postal.mailbox_vw mbvw
	ON m.id = mbvw.message_id
	LEFT JOIN labels.custom_label_vw clvw
	ON mbvw.id = clvw.mailbox_id
	WHERE (_message_id IS NULL OR m.id = _message_id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender AND (_timeline_id IS NULL OR _timeline_id > m.sender_timeline_id)
	UNION
	SELECT 
			e.message_id AS id,
			e.recipient_timeline_id AS timeline_id,
			e.recipient_email_address AS owner,
			mbvw.folder AS mailbox_folder,
			mbvw.labels AS mailbox_labels,
			clvw.labels AS custom_labels,
			e.snoozed_at AS snoozed_at,
			e.received_at AS received_at FROM mail.envelope e
	LEFT JOIN postal.mailbox_vw mbvw
	ON e.id = mbvw.envelope_id
	LEFT JOIN labels.custom_label_vw clvw
	ON mbvw.id = clvw.mailbox_id
	WHERE (_message_id IS NULL OR e.message_id = _message_id) AND (e.recipient_email_address = _owner) AND NOT e.deleted_at_recipient AND e.received_at IS NOT NULL AND (_timeline_id IS NULL OR _timeline_id > e.recipient_timeline_id)
	) u
	LEFT JOIN mail.message_vw mvw
	ON mvw.id = u.id
	LEFT JOIN mail.envelope_vw evw
	ON evw.message_id = u.id
	LEFT JOIN mail.attachment_vw avw
  	ON avw.message_id = u.id
	LEFT JOIN mail.tag_vw tvw
  	ON tvw.message_id = u.id
 	WHERE (_mailbox_folders IS NULL OR u.mailbox_folder = ANY (_mailbox_folders_arr) OR (u.mailbox_folder IS NULL AND jsonb_array_length(_mailbox_folders) = 0)) AND
		  (_mailbox_labels IS NULL OR (_mailbox_labels ?| (ARRAY(select * from jsonb_array_elements_text(u.mailbox_labels))) OR (_mailbox_labels = COALESCE(u.mailbox_labels, '[]'::jsonb)))) AND
		  (_custom_label_labels IS NULL OR (_custom_label_labels ?| (ARRAY(select * from jsonb_array_elements_text(u.custom_labels))) OR (_custom_label_labels = COALESCE(u.custom_labels, '[]'::jsonb))))
 	ORDER BY u.timeline_id DESC
	LIMIT _limit;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT * from mail.read_messages(
	'jdoe@leadict.com',			-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	NULL,							-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	NULL,							-- put the _mailbox_folders parameter value instead of '_mailbox_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "drafts"]'  -- 'or' between values -- 
	NULL,							-- put the _mailbox_labels parameter value instead of '_mailbox_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "unread", "trash"]' -- 'or' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Joe"]' -- 'or' between values --
	NULL,							-- put the _limit parameter value instead of '_limit' (int4) NULL, 20 --
	NULL							-- put the _timeline_id parameter value instead of '_timeline_id' (int8) NULL, 123 --
);
SELECT * from mail.read_messages(
	'jharper@gmail.com',			-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	NULL,							-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	NULL,							-- put the _mailbox_folders parameter value instead of '_mailbox_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "drafts"]'  -- 'or' between values -- 
	NULL,							-- put the _mailbox_labels parameter value instead of '_mailbox_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "unread", "trash"]' -- 'or' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Joe"]' -- 'or' between values --
	NULL,							-- put the _limit parameter value instead of '_limit' (int4) NULL, 20 --
	NULL							-- put the _timeline_id parameter value instead of '_timeline_id' (int8) NULL, 123 --
);
*/

CREATE OR REPLACE FUNCTION mail.read_attachment(IN _owner character varying, IN _message_id int8, IN _id int8)
  RETURNS TABLE(id int8,
                uuaid uuid,
                filename character varying,
                destination character varying,
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
				a.uuaid,
				a.filename,
				a.destination,
				a.mimetype,
				a.encoding,
				a.size
				FROM mail.read_messages(_owner, _message_id, NULL, NULL, NULL, NULL, NULL) m
				LEFT JOIN mail.attachment a
				ON m.id = a.message_id AND a.id = _id;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT *  FROM mail.read_attachment(
	'jharper@gmail.com',					-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	1,										-- put the _message_id parameter value instead of '_message_id' (int8) 123
	'70d2d183-49da-4400-8318-de0275167a80' 	-- put the _uuaid parameter value instead of '_uuaid' (uuid) 70d2d183-49da-4400-8318-de0275167a80
);
*/

CREATE OR REPLACE FUNCTION mail.delete_attachment(IN _owner character varying, IN _message_id int8, IN _id int8)
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
		) AND a.message_id = _message_id AND a.id = _id RETURNING 1
	) SELECT COUNT(*) INTO _row_cnt
	  FROM affected_rows;
	/*WITH affected_rows AS (
	        DELETE FROM mail.attachment
	        USING mail.attachment AS a
			INNER JOIN mail.message AS m
			ON a.message_id = m.id AND m.sender_email_address = _owner AND m.sent_at IS NULL AND NOT m.deleted_at_sender
			WHERE mail.attachment.id = a.id AND a.message_id = _message_id AND a.uuaid = _uuaid RETURNING m.id
	       )
	  SELECT COUNT(*) INTO _row_cnt
	  		FROM affected_rows;*/
 	RETURN _row_cnt;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT mail.delete_attachment(
	'jharper@gmail.com',					-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	4,										-- put the _message_id parameter value instead of '_message_id' (int8) 123
	'74aa8f05-f2a2-4da4-981d-e9728f7a4fc1' 	-- put the _uuaid parameter value instead of '_uuaid' (uuid) 70d2d183-49da-4400-8318-de0275167a80
);
*/

CREATE OR REPLACE FUNCTION mail.create_attachment(IN _owner character varying, IN _message_id int8, IN _attachments jsonb)
  RETURNS jsonb AS
$BODY$
DECLARE
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
									 uuaid,
									 mimetype,
									 encoding,
									 size
									 )
			SELECT
 				_message_id,
				elm->>'destination' AS destination,
				elm->>'filename' AS filename,
				(elm->>'uuaid')::uuid AS uuaid,
				elm->>'mimetype' AS mimetype,
				elm->>'encoding' AS encoding,
				(elm->>'size')::int8 AS size
			FROM jsonb_array_elements(_attachments)	elm								 
			WHERE EXISTS (	
	  			SELECT 1 FROM mail.message m WHERE m.id = _message_id AND m.sender_email_address = _owner AND m.sent_at IS NULL AND NOT m.deleted_at_sender
	  		) RETURNING *
		) SELECT jsonb_agg(jsonb_build_object('id', id,
                                		    'uuaid', uuaid,
                                		    'filename', filename,
                                		    'destination', destination,
                                		    'mimetype', mimetype,
                                		    'encoding', encoding,
                                		    'size', size
			)) FROM affected_rows ar INTO _jsonb_array;
	IF jsonb_array_length(_jsonb_array) > 0 THEN
		RETURN _jsonb_array;
	ELSE
		RETURN NULL;
	END IF;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT mail.create_attachment(
	'jdoe@leadict.com',					-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	14,										-- put the _message_id parameter value instead of '_message_id' (int8) 123
	'[
	  {
	    "filename": "Hello World.txt",
	    "encoding": "7bit",
	    "mimetype": "text/plain",
	    "destination": "./attachments/",
	    "uuaid": "98174f15-ba7a-4832-8cb8-9d5a3a88f8d1",
	    "size": 14
	  }
	]' 	-- put the _uuaid parameter value instead of '_attachments' (jsonb)
);
*/

CREATE OR REPLACE FUNCTION mail.upsert_message(IN _owner character varying, IN _id int8, IN _display_name character varying, IN _message jsonb, IN _pid int8, IN _action mail.actions)
  RETURNS int8 AS
$BODY$
DECLARE
	_ret_id int8 := 0;
	_fwd boolean := false;
	_uupmid uuid;
	_uumtid uuid;
BEGIN
	--RAISE EXCEPTION '_action: %', _action;
	--RAISE NOTICE '_action: %', _action;
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	IF _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN
		IF _action IN ('reply'::mail.actions, 'forward'::mail.actions) THEN
			IF _pid IS NULL THEN
				RAISE EXCEPTION '_pid is required.';
			ELSEIF _pid = _id THEN
				RAISE EXCEPTION '_pid and _id cannot be equal.';
			END IF;
			IF _action = 'reply'::mail.actions THEN
				SELECT uumid, uumtid FROM mail.message
					WHERE id = _pid INTO _uupmid, _uumtid;
				IF _uumtid IS NULL THEN
					RAISE NOTICE '_uumtid not found.';
				END IF;
			ELSEIF _action = 'forward'::mail.actions THEN
				_fwd := true;
				SELECT uumid FROM mail.message
					WHERE id = _pid INTO _uupmid;
			END IF;
			IF _uupmid IS NULL THEN
				RAISE NOTICE '_uupmid not found.';
			END IF;
		END IF;
		IF _uumtid IS NULL THEN
			_uumtid := public.gen_random_uuid(); 
		END IF;
	END IF;
	IF _id IS NULL THEN
		INSERT INTO mail.message (uupmid,
								 uumtid,
								 fwd, 
								 sender_email_address,
								 sender_display_name,
								 subject,
								 body,
								 sent_at)
			VALUES(_uupmid,
				_uumtid,
				_fwd,
				_owner,
				_display_name,
				_message->>'subject',
				_message->>'body',
				CASE WHEN _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN now() ELSE NULL END) RETURNING id	INTO _ret_id;
	ELSE
		UPDATE mail.message
			SET uupmid = _uupmid,
				uumtid = _uumtid,
				fwd = _fwd,
				sender_display_name = _display_name,
				subject = _message->>'subject',
				body = _message->>'body',
				sent_at = CASE WHEN _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN now() ELSE NULL END
			WHERE id = _id AND sender_email_address = _owner AND sent_at IS NULL AND NOT deleted_at_sender RETURNING id INTO _ret_id;
	END IF;
	IF _ret_id > 0 THEN
--mail.envelopes/postal.mailbox-recipient-begin--------------------			
		IF _id IS NOT NULL THEN
			-- delete from mail.envelope also deletes cascade from postal.mailbox
			--DELETE FROM postal.mailbox
			--	WHERE message_id = _ret_id AND envelope_id IS NOT NULL;
			DELETE FROM mail.envelope
				WHERE message_id = _ret_id;
		END IF;
		INSERT INTO mail.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name,
									 received_at)
			SELECT
				_ret_id,
				'to' AS type,
				to_recipient->>'email_address' AS email_address,
				to_recipient->>'display_name' AS display_name,
				CASE WHEN _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN now() ELSE NULL END
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, to}') to_recipient;
		IF _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN
			INSERT INTO postal.mailbox (owner, envelope_id,	folder)
				SELECT
					to_recipient.recipient_email_address,
					to_recipient.id,
					'inbox'::postal.mailbox_folders
				FROM mail.envelope to_recipient
				WHERE to_recipient.message_id = _ret_id AND to_recipient.type = 'to'::mail.envelope_type;
		END IF;
		INSERT INTO mail.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name,
									 received_at)
			SELECT
				_ret_id,
				'cc' AS type,
				cc_recipient->>'email_address' AS email_address,
				cc_recipient->>'display_name' AS display_name,
				CASE WHEN _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN now() ELSE NULL END
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, cc}') cc_recipient;								 
		IF _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN
			INSERT INTO postal.mailbox (owner, envelope_id,	folder)
				SELECT
					cc_recipient.recipient_email_address,
					cc_recipient.id,
					'inbox'::postal.mailbox_folders
				FROM mail.envelope cc_recipient
				WHERE cc_recipient.message_id = _ret_id AND cc_recipient.type = 'cc'::mail.envelope_type;
		END IF;
		INSERT INTO mail.envelope (message_id,
									 type,
									 recipient_email_address,
									 recipient_display_name,
									 received_at)
			SELECT
				_ret_id,
				'bcc' AS type,
				bcc_recipient->>'email_address' AS email_address,
				bcc_recipient->>'display_name' AS display_name,
				CASE WHEN _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN now() ELSE NULL END
			FROM jsonb_array_elements(_message::jsonb#>'{envelopes, bcc}') bcc_recipient;								 
		IF _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN
			INSERT INTO postal.mailbox (owner, envelope_id,	folder)
				SELECT
					bcc_recipient.recipient_email_address,
					bcc_recipient.id,
					'inbox'::postal.mailbox_folders
				FROM mail.envelope bcc_recipient
				WHERE bcc_recipient.message_id = _ret_id AND bcc_recipient.type = 'bcc'::mail.envelope_type;
		END IF;
--mail.envelopes/postal.mailbox-recipient-end--------------------			
--mail.attachment-begin------------------	
		/*IF _id IS NOT NULL THEN
			DELETE FROM mail.tag
				WHERE message_id = _ret_id;
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
			FROM jsonb_array_elements(_message::jsonb->'tags') tags;*/
--mail.attachment-end--------------------			
--mail.tag-begin------------------	
		IF _id IS NOT NULL THEN
			DELETE FROM mail.tag
				WHERE message_id = _ret_id;
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
--postal.mailbox-sender-begin--------------------			
		IF _action IN ('send'::mail.actions, 'reply'::mail.actions, 'forward'::mail.actions) THEN
			IF _id IS NULL THEN
				INSERT INTO postal.mailbox (owner,	message_id,	folder)
					VALUES(_owner, _ret_id,	'sent'::postal.mailbox_folders);
			ELSE
				UPDATE postal.mailbox
					SET folder = 'sent'::postal.mailbox_folders
					WHERE message_id = _ret_id AND owner = _owner;			
			END IF;
		ELSE
			IF _id IS NULL THEN
				INSERT INTO postal.mailbox (owner,	message_id,	folder)
					VALUES(_owner, _ret_id,	'drafts'::postal.mailbox_folders);
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

--SELECT mail.upsert_message('jdoe@leadict.com', NULL, 'John Doe', '{"body":"A message to delete X1","subject":"To delete X1","envelopes":{"to":[{"display_name":"Peter Salon","email_address":"peter.salon@gmail.com"}],"cc":[{"display_name":"Joe Harper","email_address":"jharper@gmail.com"}],"bcc":[{"display_name":"Filip Figuli","email_address":"ffiguli@leadict.com"},{"display_name":"Rastislav Filip","email_address":"rastislav.filip@gmail.com"}]},"tags":[{"type":0,"name":"invoice","value":"164/11"},{"type":1,"name":"number","value":1234}]}', NULL, 'send');
--SELECT mail.upsert_message('jdoe@leadict.com', 3, 'John Doe', '{"body":"A message to delete X1","subject":"To delete X1","envelopes":{"to":[{"display_name":"Peter Salon","email_address":"peter.salon@gmail.com"}],"cc":[{"display_name":"Joe Harper","email_address":"jharper@gmail.com"}],"bcc":[{"display_name":"Filip Figuli","email_address":"ffiguli@leadict.com"},{"display_name":"Rastislav Filip","email_address":"rastislav.filip@gmail.com"}]},"tags":[{"type":0,"name":"invoice","value":"164/11"},{"type":1,"name":"number","value":1234}]}', NULL, '{"action":"send"}'::jsonb);
--SELECT mail.upsert_message('jdoe@leadict.com', 3, 'John Doe', '{"body":"A message to delete X1","subject":"To delete X1","envelopes":{"to":[{"display_name":"Peter Salon","email_address":"peter.salon@gmail.com"}],"cc":[{"display_name":"Joe Harper","email_address":"jharper@gmail.com"}],"bcc":[{"display_name":"Filip Figuli","email_address":"ffiguli@leadict.com"},{"display_name":"Rastislav Filip","email_address":"rastislav.filip@gmail.com"}]},"tags":[{"type":0,"name":"invoice","value":"164/11"},{"type":1,"name":"number","value":1234}]}', NULL, '{"action":"send"}');

/*
SELECT * from mail.read_messages(
	'jdoe@leadict.com',			-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	NULL,							-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	NULL,							-- put the _mailbox_folders parameter value instead of '_mailbox_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "drafts"]'  -- 'or' between values -- 
	NULL,							-- put the _mailbox_labels parameter value instead of '_mailbox_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "unread", "trash"]' -- 'or' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Joe"]' -- 'or' between values --
	NULL,							-- put the _limit parameter value instead of '_limit' (int4) NULL, 20 --
	NULL							-- put the _timeline_id parameter value instead of '_timeline_id' (int8) NULL, 123 --
)
*/

CREATE OR REPLACE FUNCTION mail.delete_message(IN _owner character VARYING, IN _id int8)
  RETURNS int8 AS
$BODY$
DECLARE
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

--SELECT mail.delete_message('jharper@gmail.com', NULL);
