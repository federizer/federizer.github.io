CREATE OR REPLACE VIEW email.message_vw AS	    
SELECT m.id,
		m.uumid,
		m.uupmid,
		m.uumtid,
		m.fwd,
		jsonb_build_object('email_address', m.sender_email_address, 'display_name', m.sender_display_name) AS sender,
		m.subject,
		m.body,
		m.sender_timeline_id,
		m.sent_at,
		m.created_at,
		m.updated_at
	FROM email.message m;
	
CREATE OR REPLACE VIEW email.envelope_vw AS
SELECT e.message_id,
       jsonb_object_agg(e.type, e.recipients ORDER BY e.type) AS envelopes
FROM (SELECT envelope.message_id,
    envelope.type,
    jsonb_agg(jsonb_build_object('email_address', envelope.recipient_email_address, 'display_name', envelope.recipient_display_name, 'received_at', envelope.received_at, 'snoozed_at', envelope.snoozed_at) ORDER BY envelope.id) AS recipients
   FROM email.envelope
   GROUP BY envelope.message_id, envelope.type) e
GROUP BY e.message_id;

--https://dba.stackexchange.com/questions/51895/efficient-query-to-get-greatest-value-per-group-from-big-table?answertab=votes#tab-top
/*CREATE OR REPLACE VIEW email.attachment_vw AS	    
SELECT h.message_id,
		jsonb_agg(jsonb_build_object('id', a.id, 'uuaid', a.uuaid, 'filename', a.filename, 'destination', ac.destination, 'mimetype', a.mimetype, 'encoding', a."encoding", 'size', ac."size") ORDER BY a.id) AS attachments
FROM email.attachment a
LEFT JOIN email.has h
ON h.attachment_id = a.id
LEFT JOIN LATERAL (
	SELECT 	c.destination,
			c.size,
			c.version_major,
			c.version_minor,
			c.content
	FROM email.attachment_content c
	WHERE c.attachment_id = a.id AND c.id = h.attachment_content_id
	ORDER BY c.version_major DESC, c.version_minor DESC NULLS LAST
	LIMIT 1
	) ac ON true
GROUP BY h.message_id;*/
		
CREATE OR REPLACE VIEW email.tag_vw AS	    
SELECT message_id,
		jsonb_agg(jsonb_build_object('type', t.type, 'name', t.name, 'value', t.value) ORDER BY t.id) AS tags
FROM email.tag t
GROUP BY t.message_id;
		
CREATE OR REPLACE VIEW postal.mailbox_vw AS
SELECT mb.id,
		mb.message_id,
		mb.envelope_id,
		mb.owner,
		mb.folder,
		to_jsonb(array_remove(ARRAY[CASE WHEN mb.done THEN 'done' END,
									CASE WHEN mb.archived THEN 'archived' END,
									CASE WHEN mb.starred THEN 'starred' END,
									CASE WHEN mb.important THEN 'important' END,
									CASE WHEN mb.chats THEN 'chats' END,
									CASE WHEN mb.spam THEN 'spam' END,
									CASE WHEN mb.unread THEN 'unread' END,
									CASE WHEN mb.trash THEN 'trash' END], NULL)) AS "labels",
		(mb.done::int::bit
     || mb.archived::int::bit
     || mb.starred::int::bit
     || mb.important::int::bit
     || mb.chats::int::bit
     || mb.spam::int::bit
     || mb.unread::int::bit
     || mb.trash::int::bit)::bit(8)::int4 AS label_bits									

   FROM postal.mailbox mb;
   
CREATE OR REPLACE VIEW labels.custom_label_vw AS
SELECT h.mailbox_id,
		h.owner,
		jsonb_agg(to_jsonb(cl.name) ORDER BY cl.id) AS labels									

   FROM labels.has h
   LEFT JOIN labels.custom_label cl
   ON h.owner = cl.owner AND h.custom_label_id = cl.id
   GROUP BY h.mailbox_id, h.owner;