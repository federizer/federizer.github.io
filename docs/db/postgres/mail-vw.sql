CREATE OR REPLACE VIEW mail.message_vw AS	    
SELECT m.id,
		jsonb_build_object('email_address', m.sender_email_address, 'display_name', m.sender_display_name) AS sender,
		m.subject,
		m.body,
		m.sender_timeline_id,
		m.sent_at,
		m.created_at,
		m.updated_at
	FROM mail.message m;
	
CREATE OR REPLACE VIEW mail.envelope_vw AS
SELECT e.message_id,
       jsonb_object_agg(e.type, e.recipients ORDER BY e.type) AS envelopes
FROM (SELECT envelope.message_id,
    envelope.type,
    jsonb_agg(jsonb_build_object('email_address', envelope.recipient_email_address, 'display_name', envelope.recipient_display_name, 'received_at', envelope.received_at, 'snoozed_at', envelope.snoozed_at) ORDER BY envelope.id) AS recipients
   FROM mail.envelope
   GROUP BY envelope.message_id, envelope.type) e
GROUP BY e.message_id;

CREATE OR REPLACE VIEW mail.attachment_vw AS	    
SELECT message_id,
		jsonb_agg(jsonb_build_object('destination', a.destination, 'filename', a.filename, 'name', a.name, 'mimetype', a.mimetype, 'encoding', a."encoding", 'size', a."size") ORDER BY a.id) AS attachments
FROM mail.attachment a
GROUP BY a.message_id;
		
CREATE OR REPLACE VIEW mail.tag_vw AS	    
SELECT message_id,
		jsonb_agg(jsonb_build_object('type', t.type, 'name', t.name, 'value', t.value) ORDER BY t.id) AS tags
FROM mail.tag t
GROUP BY t.message_id;
		
CREATE OR REPLACE VIEW labels.system_label_vw AS
SELECT sl.message_id,
		sl.owner,
		sl.folder,
		to_jsonb(array_remove(ARRAY[CASE WHEN sl.done THEN 'done' END,
									CASE WHEN sl.archived THEN 'archived' END,
									CASE WHEN sl.starred THEN 'starred' END,
									CASE WHEN sl.important THEN 'important' END,
									CASE WHEN sl.chats THEN 'chats' END,
									CASE WHEN sl.spam THEN 'spam' END,
									CASE WHEN sl.unread THEN 'unread' END,
									CASE WHEN sl.trash THEN 'trash' END], NULL)) AS "labels",
		(sl.done::int::bit
     || sl.archived::int::bit
     || sl.starred::int::bit
     || sl.important::int::bit
     || sl.chats::int::bit
     || sl.spam::int::bit
     || sl.unread::int::bit
     || sl.trash::int::bit)::bit(8)::int4 AS label_bits									

   FROM labels.system_label sl;
   
CREATE OR REPLACE VIEW labels.custom_label_vw AS
SELECT h.message_id,
		h.owner,
		jsonb_agg(to_jsonb(cl.name) ORDER BY cl.id) AS labels									

   FROM labels.has h
   LEFT JOIN labels.custom_label cl
   ON h.owner = cl.owner AND h.custom_label_id = cl.id
   GROUP BY h.message_id, h.owner;