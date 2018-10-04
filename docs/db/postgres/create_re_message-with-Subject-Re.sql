CREATE OR REPLACE FUNCTION "postal"."create_re_message"(IN "old_id" int8, IN "identity" varchar, IN "folder" varchar, OUT "id" int8, OUT "body" jsonb)
  RETURNS "pg_catalog"."record" AS $BODY$
	DECLARE
		folder_filter jsonb;
		sender jsonb;
		old_msg_subject jsonb;
		old_msg_body jsonb;
		new_msg_subject jsonb;
		new_msg_body jsonb;
		old_envelopes jsonb;
		old_envelope jsonb;
		new_sender jsonb;
		new_envelopes jsonb;
		new_body jsonb;
		i int4;
		j int4;
begin
IF folder = 'inbox' THEN
	folder_filter = '{"envelopes": [{"recipient": {"email_address": "' || $2 || '"}}]}';
	RAISE NOTICE 'folder_filter for ''inbox'': %',folder_filter;

	SELECT
	m.body->'sender', m.body->'subject', m.body->'body', m.body->'envelopes'
	FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter AND m.body ? 'sent_at'
	AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
	INTO sender, old_msg_subject, old_msg_body, old_envelopes;
	
  new_msg_subject = jsonb_build_object('subject', old_msg_subject #>> '{}' || ' :Re');
  new_msg_body = jsonb_build_object('body', old_msg_body);
	RAISE NOTICE 'new_msg_subject: %', new_msg_subject;
	RAISE NOTICE 'new_msg_body: %', new_msg_body;
	
	RAISE NOTICE 'envelopes: %', old_envelopes;
	i = 0;
	j = -1;
	FOR old_envelope IN SELECT * FROM jsonb_array_elements(old_envelopes)
  LOOP
    RAISE NOTICE '%. old_envelope.recipient.email_address: %', i, old_envelope->'recipient'->'email_address';
    RAISE NOTICE '%. element from old_envelopes: %', i, old_envelope;
		IF old_envelope->'recipient'->'email_address' ? identity THEN
			j = i;
		END IF;
		i = i + 1;
  END LOOP;
	IF j >= 0 THEN
   	-- RAISE NOTICE 'old_envelopes.recipient: %', old_envelopes->'recipient';
		new_sender = jsonb_build_object('sender', old_envelopes->j->'recipient');
	  new_envelopes = old_envelopes - j;
	END IF;
	new_envelopes = jsonb_build_object('envelopes', new_envelopes || jsonb_build_object('recipient', sender));
  RAISE NOTICE 'new_sender: %', new_sender;
	RAISE NOTICE 'new_envelopes: %', new_envelopes;

  new_body = new_sender || new_msg_subject || new_msg_body || new_envelopes;
  RAISE NOTICE 'new_body: %', new_body;

  IF new_body IS NOT NULL THEN
		INSERT INTO postal.messages(body)
		VALUES(new_body)
		RETURNING postal.messages.id, postal.messages.body INTO create_re_message.id, create_re_message.body;
  END IF;
ELSIF folder = 'sent' THEN
	folder_filter = '{"sender": {"email_address": "' || $2 || '"}}';
	RAISE NOTICE 'folder_filter for ''sent'' %',folder_filter;

	INSERT INTO postal.messages(body)
	SELECT
	 jsonb_build_object('sender', m.body->'sender') ||
	 jsonb_build_object('subject', m.body->'subject' #>> '{}' || ' :Re') ||
	 jsonb_build_object('body', m.body->'body') ||
	 jsonb_build_object('envelopes', m.body->'envelopes')
	FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter AND m.body ? 'sent_at'
	AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
	RETURNING postal.messages.id, postal.messages.body INTO create_re_message.id, create_re_message.body;
ELSE
  RAISE EXCEPTION 'Unsupported folder: %', folder USING HINT = 'Only ''inbox'' or ''sent'' are allowed';
END IF;

end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100