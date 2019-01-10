CREATE OR REPLACE FUNCTION mail.read_message(IN _owner character varying, IN _message_id int8, IN _system_label_folder labels.folders, IN _system_label_label_bits int4, IN _custom_label jsonb)
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
begin
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;
	RETURN QUERY
	SELECT m.id,
			m.sender,
			m.subject,
			m.body,
			e.envelopes,
			sl.folder AS system_folder,
			sl.labels AS system_labels,
			cl.labels AS custom_labels,
			a.attachments,
			t.tags,
			m.sent_at,
			m.created_at,
			m.updated_at
	FROM (SELECT mail.message.id FROM mail.message WHERE mail.message.sender_email_address = _owner
	UNION SELECT mail.envelope.message_id FROM mail.envelope WHERE mail.envelope.recipient_email_address = _owner) u
	LEFT JOIN mail.message_vw m
	ON u.id = m.id
	LEFT JOIN mail.envelope_vw e
  	ON u.id = e.message_id
	LEFT JOIN mail.attachment_vw a
  	ON u.id = a.message_id
	LEFT JOIN mail.tag_vw t
  	ON u.id = t.message_id
	LEFT JOIN labels.system_label_vw sl
  	ON u.id = sl.message_id AND sl.owner = _owner
	LEFT JOIN labels.custom_label_vw cl
  	ON u.id = cl.message_id AND cl.owner = _owner
	WHERE (_message_id IS NULL OR u.id = _message_id) AND
		  (_system_label_folder IS NULL OR sl.folder = _system_label_folder) AND
		  (_system_label_label_bits IS NULL OR (sl.label_bits & _system_label_label_bits) > 0 OR (COALESCE(sl.label_bits, 0) | _system_label_label_bits) = 0) AND
		  (_custom_label IS NULL OR _custom_label ?| (ARRAY(select * from jsonb_array_elements_text(cl.labels))) OR (_custom_label = COALESCE(cl.labels, '[]'::jsonb)));
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

/*SELECT * from mail.read_message(
	:_owner,	-- put the _owner parameter value instead of '_owner' (varchar) izboran@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	:_message_id,	-- put the _message_id parameter value instead of '_message_id' (int8) NULL, 123
	:_system_label_folder,	-- put the _system_label_folder parameter value instead of '_system_label_folder' (folders) NULL, 'inbox', 'snoozed', 'sent', 'drafts'
	:_system_label_label_bits,	-- put the _system_label_label_bits parameter value instead of '_system_label_label_bits' (int4) NULL, 0, 123
	:_custom_label 	-- put the _custom_label parameter value instead of '_custom_label' (jsonb) NULL, '[]', '["John Doe", "Igor"]'
);*/


