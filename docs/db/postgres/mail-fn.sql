--CREATE OR REPLACE FUNCTION mail.read_message(IN _owner character varying, IN _message_id int8, IN IN q character varying, IN _limit int4, IN _page_token  character varying)
CREATE OR REPLACE FUNCTION mail.read_message(IN _owner character varying, IN _message_id int8, IN _system_label_folders jsonb, IN _system_label_labels jsonb, IN _custom_label_labels jsonb, IN _limit int4)
  RETURNS TABLE(id int8,
				sender jsonb,
                subject text,
                body text,
                envelopes jsonb,
                system_folder labels.folders,
                system_labels jsonb,
                custom_labels jsonb,
                attachments jsonb,
                tags jsonb,
                sent_at timestamptz,
                created_at timestamptz,
                updated_at timestamptz) AS
$BODY$
DECLARE
	_system_label_folders_arr labels.folders[4];
	_system_label_labels_arr labels.labels[8];
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
	IF _limit IS NULL OR _limit > 100 THEN
		_limit = 100;
	END IF;
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
			mu.sent_at,
			mu.created_at,
			mu.updated_at
	FROM (SELECT m.id,
			m.sender,
			m.subject,
			m.body,
			m.sent_at,
			m.created_at,
			m.updated_at
	FROM (SELECT mail.message.id,  mail.message.sender_email_address AS sender_email_address FROM mail.message WHERE mail.message.sender_email_address = _owner
	UNION SELECT mail.envelope.message_id, NULL FROM mail.envelope WHERE mail.envelope.recipient_email_address = _owner) u
	LEFT JOIN mail.message_vw m
	ON u.id = m.id --AND (u.sender_email_address = _owner OR m.sent_at IS NOT NULL) // doesn't work
	WHERE (u.sender_email_address = _owner OR m.sent_at IS NOT NULL)) mu
	LEFT JOIN mail.envelope_vw e
  	ON mu.id = e.message_id
	LEFT JOIN mail.attachment_vw a
  	ON mu.id = a.message_id
	LEFT JOIN mail.tag_vw t
  	ON mu.id = t.message_id
	LEFT JOIN labels.system_label_vw sl
  	ON mu.id = sl.message_id AND sl.owner = _owner
	LEFT JOIN labels.custom_label_vw cl
  	ON mu.id = cl.message_id AND cl.owner = _owner
	WHERE (_message_id IS NULL OR mu.id = _message_id) AND
		  (_system_label_folders IS NULL OR sl.folder = ANY (_system_label_folders_arr) OR (sl.folder IS NULL AND jsonb_array_length(_system_label_folders) = 0)) AND
		  --(_system_label_label_bits IS NULL OR (sl.label_bits & _system_label_label_bits) > 0 OR (COALESCE(sl.label_bits, 0) | _system_label_label_bits) = 0) AND
		  (_system_label_labels IS NULL OR (_system_label_labels ?& (ARRAY(select * from jsonb_array_elements_text(sl.labels))) AND (_system_label_labels = COALESCE(sl.labels, '[]'::jsonb)))) AND
		  (_custom_label_labels IS NULL OR (_custom_label_labels ?| (ARRAY(select * from jsonb_array_elements_text(cl.labels))) OR (_custom_label_labels = COALESCE(cl.labels, '[]'::jsonb))))
	ORDER BY mu.sent_at DESC, mu.updated_at DESC, mu.created_at DESC, mu.id DESC
	LIMIT _limit;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT * from mail.read_message(
	'jdoe@leadict.com',				-- put the _owner parameter value instead of '_owner' (varchar) izboran@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	NULL,							-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	NULL,							-- put the _system_label_folders parameter value instead of '_system_label_folders' (jsonb) NULL, '[]', '["inbox", "snoozed", "sent", "drafts"]'  -- 'or' between values -- 
	NULL,							-- put the _system_label_labels parameter value instead of '_system_label_labels' (jsonb) NULL, '[]', '["done", "archived", "starred", "important", "chats", "spam", "trash", "unread"]' -- 'and' between values --
	NULL, 							-- put the _custom_label_labels parameter value instead of '_custom_label_labels' (jsonb) NULL, '[]', '["John Doe", "Igor"]' -- 'or' between values --
	NULL							-- put the _limit parameter value instead of '_limit' (int4) NULL, 100 -- max. value is 100 --
)
*/



