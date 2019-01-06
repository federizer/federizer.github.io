CREATE OR REPLACE FUNCTION mail.read_message(IN _owner character varying, IN _message_id int8, IN _system_label_folder labels.folders, IN _system_label_status int2, IN _user_label character varying)
  RETURNS TABLE(id int8,
				sender jsonb,
                subject text,
                body text,
                recipient jsonb,
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
				mail.message.created_at,
				mail.message.updated_at
	FROM mail.message LEFT JOIN (SELECT
			mail.envelope.message_id AS message_id,
			mail.envelope.type AS type,
	    json_agg(jsonb_build_object('email_address', mail.envelope.recipient_email_address, 'display_name', mail.envelope.recipient_display_name) ORDER BY mail.envelope.id) 
	         AS recipient
	FROM
	    mail.envelope 
	GROUP BY
	    mail.envelope.message_id, mail.envelope.type) s
	ON mail.message.id = s.message_id
	WHERE _message_id IS NULL OR mail.message.id = _message_id    
	GROUP BY
	    mail.message.id;
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