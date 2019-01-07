CREATE OR REPLACE FUNCTION mail.read_message(IN _owner character varying, IN _message_id int8, IN _system_label_folder labels.folders, IN _system_label_status int2, IN _user_label character varying)
  RETURNS TABLE(id int8,
				sender jsonb,
                subject text,
                body text,
                recipient jsonb,
                folder labels.folders,
                label jsonb,
                sent_at timestamptz,
                created_at timestamptz,
                updated_at timestamptz) AS
$BODY$
begin
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	RETURN QUERY
	SELECT mail.message.id,
				jsonb_build_object('email_address', mail.message.sender_email_address, 'display_name', mail.message.sender_display_name) AS sender,
				mail.message.subject,
				mail.message.body,
				jsonb_object_agg(type, s.recipient ORDER BY type) AS recipient,
				labels.system_label.folder AS folder,
				--jsonb_build_array(CASE WHEN labels.system_label.done THEN 'done' END, CASE WHEN labels.system_label.unread THEN 'unread' END) AS label,
				to_jsonb(array_remove(ARRAY[CASE WHEN labels.system_label.done THEN 'done' ELSE NULL END, CASE WHEN labels.system_label.unread THEN 'unread' ELSE NULL END], NULL)) AS label,
				mail.message.sent_at,
				mail.message.created_at,
				mail.message.updated_at
	FROM mail.message LEFT JOIN (SELECT
			mail.envelope.message_id AS message_id,
			mail.envelope.type AS type,
	    jsonb_agg(jsonb_build_object('email_address', mail.envelope.recipient_email_address, 'display_name', mail.envelope.recipient_display_name) ORDER BY mail.envelope.id) 
	         AS recipient
	FROM
	    mail.envelope 
	GROUP BY
	    mail.envelope.message_id, mail.envelope.type) s
	ON mail.message.id = s.message_id
	LEFT JOIN labels.system_label
  	ON mail.message.id = labels.system_label.message_id
	WHERE (_message_id IS NULL OR mail.message.id = _message_id) AND
		  (mail.message.sender_email_address = _owner OR (mail.message.sent_at IS NOT NULL AND s.recipient @> ('[{"email_address":"' || _owner || '"}]')::jsonb)) AND
		  (_system_label_folder IS NULL OR (labels.system_label.folder = _system_label_folder AND labels.system_label.owner = _owner))
	GROUP BY
	    mail.message.id, labels.system_label.folder, labels.system_label.done, labels.system_label.unread;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*SELECT * from mail.read_message(
	:_owner,	-- put the _owner parameter value instead of '_owner' (varchar)
	:_message_id,	-- put the _message_id parameter value instead of '_message_id' (int8)
	:_system_label_folder,	-- put the _system_label_folder parameter value instead of '_system_label_folder' (folders)
	:_system_label_status,	-- put the _system_label_status parameter value instead of '_system_label_status' (int2)
	:_user_label 	-- put the _user_label parameter value instead of '_user_label' (varchar)
);*/