CREATE OR REPLACE FUNCTION mail.read_envelopes(IN _owner character varying, IN _message_id int8)
  RETURNS TABLE(message_id int8,
                envelopes jsonb,
                received_at timestamptz,
                snoozed_at timestamptz,                
                recipient_timeline_id int8) AS
$BODY$
BEGIN
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
                sender_timeline_id int8,
				recipient_timeline_id int8,
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
	SELECT  mu.id,
			mu.sender,
			mu.subject,
			mu.body,
			e.envelopes,
			sl.folder AS system_folder,
			sl.labels AS system_labels,
			cl.labels AS custom_labels,
			a.attachments,
			t.tags,
			mu.sender_timeline_id,
			e.recipient_timeline_id,
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
	FROM (SELECT mail.message.id,  mail.message.sender_email_address AS sender_email_address FROM mail.message WHERE mail.message.sender_email_address = _owner
	UNION SELECT mail.envelope.message_id, NULL FROM mail.envelope WHERE mail.envelope.recipient_email_address = _owner) u
	LEFT JOIN mail.message_vw m
	ON u.id = m.id
	WHERE (u.sender_email_address = _owner OR m.sent_at IS NOT NULL)) mu
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
	NULL,							-- put the _system_label_folders parameter value instead of '_system_label_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "drafts"]'  -- 'or' between values -- 
	NULL,							-- put the _system_label_labels parameter value instead of '_system_label_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "trash", "unread"]' -- 'or' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Igor"]' -- 'or' between values --
	NULL,							-- put the _limit parameter value instead of '_limit' (int4) NULL, 20 --
	NULL							-- put the _timeline_id parameter value instead of '_timeline_id' (int8) NULL, 123 --
)
*/



