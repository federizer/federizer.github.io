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
    	m.search_subject,
    	m.search_body,
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
/*CREATE OR REPLACE VIEW email.file_vw AS	    
SELECT a.message_id,
		jsonb_agg(jsonb_build_object('id', f.id, 'uufid', f.uufid, 'filename', f.filename, 'destination', fc.destination, 'mimetype', f.mimetype, 'encoding', f."encoding", 'size', fc."size") ORDER BY f.id) AS files
FROM repository.file f
LEFT JOIN email.attachment a
ON a.file_id = f.id
LEFT JOIN LATERAL (
	SELECT 	c.destination,
			c.size,
			c.version_major,
			c.version_minor,
			c.content
	FROM repository.file_content c
	WHERE c.file_id = f.id AND c.id = a.file_content_id
	ORDER BY c.version_major DESC, c.version_minor DESC NULLS LAST
	LIMIT 1
	) fc ON true
GROUP BY a.message_id;*/
		
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
     || mb.trash::int::bit)::bit(8)::int4 AS label_bits --this doesn't work (due to null values)

   FROM postal.mailbox mb;
   
CREATE OR REPLACE VIEW labels.custom_label_vw AS
SELECT h.mailbox_id,
		h.owner,
		jsonb_agg(to_jsonb(cl.name) ORDER BY cl.id) AS labels									

   FROM labels.has h
   LEFT JOIN labels.custom_label cl
   ON h.owner = cl.owner AND h.custom_label_id = cl.id
   GROUP BY h.mailbox_id, h.owner;

CREATE OR REPLACE VIEW contacts.people_groups_vw AS  
	SELECT g.id, b.owner, b.person_id, g.name FROM contacts.belongs b
	LEFT JOIN contacts.group g ON
	b.group_id = g.id AND b."owner" = g."owner";

CREATE OR REPLACE VIEW contacts.groups_people_vw AS  
	SELECT p.id, b.owner, b.group_id, p.given_name, p.surname, p.email_address FROM contacts.belongs b
	LEFT JOIN contacts.person p ON
	b.person_id = p.id AND b."owner" = p."owner";
	
CREATE OR REPLACE VIEW filters.filter_vw AS
SELECT 	f.id,
		f.owner,
		f.name,
		f.criteria,
		/*to_jsonb(array_remove(ARRAY[CASE WHEN pla.done THEN 'done' END,
									CASE WHEN pla.archived THEN 'archived' END,
									CASE WHEN pla.starred THEN 'starred' END,
									CASE WHEN pla.important THEN 'important' END,
									CASE WHEN pla.chats THEN 'chats' END,
									CASE WHEN pla.spam THEN 'spam' END,
									CASE WHEN pla.unread THEN 'unread' END,
									CASE WHEN pla.trash THEN 'trash' END], NULL)) AS "postal_label_actions",*/
		jsonb_build_object(	'done', pla.done,
							'archived', pla.archived,
							'starred', pla.starred,
							'important', pla.important,
							'chats', pla.chats,
							'spam', pla.spam,
							'unread', pla.unread,
							'trash', pla.trash) AS postal_labels,
		COALESCE(claa.add_custom_label_ids, '[]'::jsonb) AS add_custom_label_ids,
		COALESCE(clar.remove_custom_label_ids, '[]'::jsonb) AS remove_custom_label_ids
   FROM filters.filter f
   LEFT JOIN filters.postal_label_action pla
   ON pla.owner = f.owner AND pla.filter_id = f.id
   LEFT JOIN LATERAL (
	SELECT 	cla."owner",
			cla.filter_id,
			jsonb_build_object('custom_label_ids', jsonb_agg(cla.custom_label_id ORDER BY cla.custom_label_id)) AS add_custom_label_ids
	FROM filters.custom_label_action cla
	WHERE cla.custom_label_action = 'add'::filters.custom_label_actions
	GROUP BY cla."owner", cla.filter_id
	) claa
   ON claa.owner = f.owner AND claa.filter_id = f.id
   LEFT JOIN LATERAL (
	SELECT 	cla."owner",
			cla.filter_id,
			jsonb_build_object('custom_label_ids', jsonb_agg(cla.custom_label_id ORDER BY cla.custom_label_id)) AS remove_custom_label_ids
	FROM filters.custom_label_action cla
	WHERE cla.custom_label_action = 'remove'::filters.custom_label_actions
	GROUP BY cla."owner", cla.filter_id
	) clar
   ON clar.owner = f.owner AND clar.filter_id = f.id;

