CREATE OR REPLACE VIEW mail.email AS
SELECT mail.message.id,
			jsonb_build_object('email_address', mail.message.sender_email_address, 'display_name', mail.message.sender_display_name) AS sender,
			mail.message.subject,
			mail.message.body,
			jsonb_object_agg(type, recipient ORDER BY type) AS recipient,
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
GROUP BY
    mail.message.id;