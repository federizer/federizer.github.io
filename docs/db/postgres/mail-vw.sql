CREATE OR REPLACE VIEW mail.message_vw AS	    
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
		jsonb_agg(jsonb_build_object('id', a.id, 'uuaid', a.uuaid, 'filename', a.filename, 'destination', a.destination, 'mimetype', a.mimetype, 'encoding', a."encoding", 'size', a."size") ORDER BY a.id) AS attachments
FROM mail.attachment a
GROUP BY a.message_id;
		
CREATE OR REPLACE VIEW mail.tag_vw AS	    
SELECT message_id,
		jsonb_agg(jsonb_build_object('type', t.type, 'name', t.name, 'value', t.value) ORDER BY t.id) AS tags
FROM mail.tag t
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