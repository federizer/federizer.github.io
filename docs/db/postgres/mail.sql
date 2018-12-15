--
-- TOC entry 9 (class 2615 OID 16444)
-- Name: mail; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA mail;


--
-- TOC entry 225 (class 1255 OID 16528)
-- Name: create_fw_message(bigint, character varying, character varying); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.create_fw_message(old_id bigint, identity character varying, folder character varying, OUT id bigint, OUT body jsonb) RETURNS record
    LANGUAGE plpgsql
    AS $_$
	DECLARE
		folder_filter jsonb;
		sender jsonb;
		old_msg_subject jsonb;
		old_msg_body jsonb;
		new_msg_subject jsonb;
		new_msg_body jsonb;
		old_attachments jsonb;
		new_attachments jsonb;
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
	m.body->'sender', m.body->'subject', m.body->'body', m.body->'envelopes', m.body->'attachments'
	FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter AND m.body ? 'sent_at'
	AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
	INTO sender, old_msg_subject, old_msg_body, old_envelopes, old_attachments;
	
  new_msg_subject = jsonb_build_object('subject', old_msg_subject);
  new_msg_body = jsonb_build_object('body', old_msg_body);
	RAISE NOTICE 'new_msg_subject: %', new_msg_subject;
	RAISE NOTICE 'new_msg_body: %', new_msg_body;
	
	RAISE NOTICE 'old_envelopes: %', old_envelopes;
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

  new_attachments = jsonb_build_object('attachments', old_attachments);
	
  new_body = new_sender || new_msg_subject || new_msg_body || new_attachments;
  RAISE NOTICE 'new_body: %', new_body;

  IF new_body IS NOT NULL THEN
		INSERT INTO mail.message(body)
		VALUES(new_body)
		RETURNING mail.message.id, mail.message.body INTO create_fw_message.id, create_fw_message.body;
  END IF;
ELSIF folder = 'sent' THEN
	folder_filter = '{"sender": {"email_address": "' || $2 || '"}}';
	RAISE NOTICE 'folder_filter for ''sent'' %',folder_filter;

	INSERT INTO mail.message(body)
	SELECT
	 jsonb_build_object('sender', m.body->'sender') ||
	 jsonb_build_object('subject', m.body->'subject') ||
	 jsonb_build_object('body', m.body->'body') ||
	 jsonb_build_object('attachments', m.body->'attachments')
	FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter AND m.body ? 'sent_at'
	AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
	RETURNING mail.message.id, mail.message.body INTO create_fw_message.id, create_fw_message.body;
ELSE
  RAISE EXCEPTION 'Unsupported folder: %', folder USING HINT = 'Only ''inbox'' or ''sent'' are allowed';
END IF;

end;
$_$;


--
-- TOC entry 226 (class 1255 OID 16529)
-- Name: create_re_message(bigint, character varying, character varying); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.create_re_message(old_id bigint, identity character varying, folder character varying, OUT id bigint, OUT body jsonb) RETURNS record
    LANGUAGE plpgsql
    AS $_$
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
	FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter AND m.body ? 'sent_at'
	AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
	INTO sender, old_msg_subject, old_msg_body, old_envelopes;
	
  new_msg_subject = jsonb_build_object('subject', old_msg_subject);
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
		INSERT INTO mail.message(body)
		VALUES(new_body)
		RETURNING mail.message.id, mail.message.body INTO create_re_message.id, create_re_message.body;
  END IF;
ELSIF folder = 'sent' THEN
	folder_filter = '{"sender": {"email_address": "' || $2 || '"}}';
	RAISE NOTICE 'folder_filter for ''sent'' %',folder_filter;

	INSERT INTO mail.message(body)
	SELECT
	 jsonb_build_object('sender', m.body->'sender') ||
	 jsonb_build_object('subject', m.body->'subject') ||
	 jsonb_build_object('body', m.body->'body') ||
	 jsonb_build_object('envelopes', m.body->'envelopes')
	FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter AND m.body ? 'sent_at'
	AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
	RETURNING mail.message.id, mail.message.body INTO create_re_message.id, create_re_message.body;
ELSE
  RAISE EXCEPTION 'Unsupported folder: %', folder USING HINT = 'Only ''inbox'' or ''sent'' are allowed';
END IF;

end;
$_$;


--
-- TOC entry 227 (class 1255 OID 16530)
-- Name: jsonb_merge(jsonb, jsonb); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.jsonb_merge(a jsonb, b jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
select
    jsonb_object_agg(
        coalesce(ka, kb),
        case
            when va isnull then vb
            when vb isnull then va
            else va || vb
        end
    )
    from jsonb_each(a) e1(ka, va)
    full join jsonb_each(b) e2(kb, vb) on ka = kb
$$;


--
-- TOC entry 211 (class 1255 OID 16531)
-- Name: jsonb_merge_deep(jsonb, jsonb); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.jsonb_merge_deep(jsonb, jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $_$
  select case jsonb_typeof($1)
    when 'object' then case jsonb_typeof($2)
      when 'object' then (
        select    jsonb_object_agg(k, case
                    when e2.v is null then e1.v
                    when e1.v is null then e2.v
                    else mail.jsonb_merge_deep(e1.v, e2.v)
                  end)
        from      jsonb_each($1) e1(k, v)
        full join jsonb_each($2) e2(k, v) using (k)
      )
      else $2
    end
    when 'array' then $1 || $2
    else $2
  end
$_$;


--
-- TOC entry 210 (class 1255 OID 16532)
-- Name: jsonb_recursive_merge(jsonb, jsonb); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.jsonb_recursive_merge(a jsonb, b jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$ 
select 
    jsonb_object_agg(
        coalesce(ka, kb), 
        case 
            when va isnull then vb 
            when vb isnull then va 
            when jsonb_typeof(va) <> 'object' or jsonb_typeof(vb) <> 'object' then vb 
            else mail.jsonb_recursive_merge(va, vb) end 
        ) 
    from jsonb_each(a) e1(ka, va) 
    full join jsonb_each(b) e2(kb, vb) on ka = kb 
$$;


--
-- TOC entry 228 (class 1255 OID 16533)
-- Name: jsonb_recursive_merge2(jsonb, jsonb); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.jsonb_recursive_merge2(a jsonb, b jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	DECLARE passed "pg_catalog"."jsonb";
begin	
select 
    jsonb_object_agg(
        coalesce(ka, kb), 
        case 
            when va isnull then vb 
            when vb isnull then va 
            when jsonb_typeof(va) <> 'object' or jsonb_typeof(vb) <> 'object' then vb 
            else mail.jsonb_recursive_merge(va, vb) end 
        )
		into passed
    from jsonb_each(a) e1(ka, va) 
    full join jsonb_each(b) e2(kb, vb) on ka = kb;
		
		return passed;
end;	
$$;


--
-- TOC entry 230 (class 1255 OID 16535)
-- Name: message_table_inserted(); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.message_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	DECLARE
	search_from TEXT;
	search_to TEXT;
	search_cc TEXT;
	search_bcc TEXT;
	search_body text;
	search_attachment_name text;
	search_tag_name text;
	search_tag_value text;
	begin		
	search_from = (NEW.body->'sender'->'display_name')::text ||
	', ' ||
	(NEW.body->'sender'->'email_address')::text;
	search_body = regexp_replace(
        regexp_replace((NEW.body->'body')::text, E'(?x)<[^>]*?(\s alt \s* = \s* ([\'"]) ([^>]*?) \2) [^>]*? >', E'\3'), 
       E'(?x)(< [^>]*? >)', '', 'g');
	SELECT string_agg((JsonString->'recipient'->'display_name')::text ||
		(JsonString->'recipient'->'email_address')::text, ', ')
		into search_to
		FROM jsonb_array_elements(NEW.body->'envelopes'->'to') JsonString;
	SELECT string_agg((JsonString->'recipient'->'display_name')::text ||
		(JsonString->'recipient'->'email_address')::text, ', ')
		into search_cc
		FROM jsonb_array_elements(NEW.body->'envelopes'->'cc') JsonString;
	SELECT string_agg((JsonString->'recipient'->'display_name')::text ||
		(JsonString->'recipient'->'email_address')::text, ', ')
		into search_bcc
		FROM jsonb_array_elements(NEW.body->'envelopes'->'bcc') JsonString;
	SELECT string_agg((JsonString->'originalname')::text, ', ')
		into search_attachment_name
		FROM jsonb_array_elements(NEW.body->'attachments') JsonString;
	SELECT string_agg((JsonString->'tag'->'name')::text, ', ')
		into search_tag_name
		FROM jsonb_array_elements(NEW.body->'tags') JsonString;	
	SELECT string_agg((JsonString->'tag'->'value')::text, ', ')
		into search_tag_value
		FROM jsonb_array_elements(NEW.body->'tags') JsonString;

	NEW.search_from = to_tsvector(search_from);
  	NEW.search_to = to_tsvector(search_to);
  	NEW.search_cc = to_tsvector(search_cc);
  	NEW.search_bcc = to_tsvector(search_bcc);
  	NEW.search_subject = to_tsvector((NEW.body->'subject')::text);
  	NEW.search_body = to_tsvector(search_body);
  	NEW.search_attachment_name = to_tsvector(search_attachment_name);
  	--NEW.search_attachment_content = to_tsvector((NEW.body->'attachments')::text);
  	NEW.search_tag_name = to_tsvector(search_tag_name);
	NEW.search_tag_value = to_tsvector(search_tag_value);
  	--NEW.search_label = to_tsvector((NEW.body->'labels')::text);

	RETURN NEW;

	END; $$;


--
-- TOC entry 231 (class 1255 OID 16536)
-- Name: message_table_updated(); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.message_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ 

	DECLARE
	search_from TEXT;
	search_to TEXT;
	search_cc TEXT;
	search_bcc TEXT;
	search_body text;
	search_attachment_name text;
	search_tag_name text;
	search_tag_value text;
	BEGIN

  	NEW.updated_at = now();

	search_from = (NEW.body->'sender'->'display_name')::text ||
	', ' ||
	(NEW.body->'sender'->'email_address')::text;
	search_body = regexp_replace(
        regexp_replace((NEW.body->'body')::text, E'(?x)<[^>]*?(\s alt \s* = \s* ([\'"]) ([^>]*?) \2) [^>]*? >', E'\3'), 
       E'(?x)(< [^>]*? >)', '', 'g');
	SELECT string_agg((JsonString->'recipient'->'display_name')::text ||
		(JsonString->'recipient'->'email_address')::text, ', ')
		into search_to
		FROM jsonb_array_elements(NEW.body->'envelopes'->'to') JsonString;
	SELECT string_agg((JsonString->'recipient'->'display_name')::text ||
		(JsonString->'recipient'->'email_address')::text, ', ')
		into search_cc
		FROM jsonb_array_elements(NEW.body->'envelopes'->'cc') JsonString;
	SELECT string_agg((JsonString->'recipient'->'display_name')::text ||
		(JsonString->'recipient'->'email_address')::text, ', ')
		into search_bcc
		FROM jsonb_array_elements(NEW.body->'envelopes'->'bcc') JsonString;
	SELECT string_agg((JsonString->'originalname')::text, ', ')
		into search_attachment_name
		FROM jsonb_array_elements(NEW.body->'attachments') JsonString;
	SELECT string_agg((JsonString->'tag'->'name')::text, ', ')
		into search_tag_name
		FROM jsonb_array_elements(NEW.body->'tags') JsonString;	
	SELECT string_agg((JsonString->'tag'->'value')::text, ', ')
		into search_tag_value
		FROM jsonb_array_elements(NEW.body->'tags') JsonString;

  	NEW.search_from = to_tsvector(search_from);
  	NEW.search_to = to_tsvector(search_to);
  	NEW.search_cc = to_tsvector(search_cc);
  	NEW.search_bcc = to_tsvector(search_bcc);
  	NEW.search_subject = to_tsvector((NEW.body->'subject')::text);
  	NEW.search_body = to_tsvector(search_body);
  	NEW.search_attachment_name = to_tsvector(search_attachment_name);
  	--NEW.search_attachment_content = to_tsvector((NEW.body->'attachments')::text);
  	NEW.search_tag_name = to_tsvector(search_tag_name);
    NEW.search_tag_value = to_tsvector(search_tag_value);
  	--NEW.search_label = to_tsvector((NEW.body->'labels')::text);

    RETURN NEW; 

	END; $$;


--
-- TOC entry 229 (class 1255 OID 16534)
-- Name: set_properties(bigint, character varying, character varying, jsonb); Type: FUNCTION; Schema: mail; Owner: -
--

CREATE FUNCTION mail.set_properties(INOUT id bigint, identity character varying, folder character varying, properties jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
	DECLARE
		id_verified int8;
  	folder_filter_sender jsonb;
		folder_filter_recipient jsonb;
BEGIN
	id_verified = NULL;

	folder_filter_sender = '{"sender": {"email_address": "' || $2 || '"}}';
	folder_filter_recipient = '{"envelopes": [{"recipient": {"email_address": "' || $2 || '"}}]}';
	RAISE NOTICE 'folder_filter_sender for ''sent'' and ''draft'': %', folder_filter_sender;
	RAISE NOTICE 'folder_filter_recipient for ''inbox'': %', folder_filter_recipient;
	
IF folder = 'inbox' THEN
		SELECT m.id
		FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter_recipient AND m.body ? 'sent_at'
		AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
		INTO id_verified;
	ELSIF folder = 'sent' THEN
		SELECT m.id
		FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter_sender AND m.body ? 'sent_at'
		AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
		INTO id_verified;
  ELSIF folder = 'draft' THEN
		SELECT m.id
		FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter_sender AND NOT m.body ? 'sent_at'
		AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
		INTO id_verified;
	ELSIF folder = 'trash' THEN
	  -- inbox
		SELECT m.id
		FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter_recipient AND m.body ? 'sent_at'
		AND m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb)
		INTO id_verified;
	  
		IF id_verified IS NULL THEN
  	  -- sent
			SELECT m.id
			FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter_sender AND m.body ? 'sent_at'
  		AND m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb)
			INTO id_verified;
			
  		IF id_verified IS NULL THEN
    	  -- draft
				SELECT m.id
				FROM mail.message m WHERE m.id = $1 AND m.body @> folder_filter_sender AND NOT m.body ? 'sent_at'
    		AND m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb)
				INTO id_verified;
			END IF;
		END IF;		
	ELSE
		RAISE EXCEPTION 'Unsupported folder: %', folder USING HINT = 'Only ''inbox'', ''sent'' , ''draft''  or ''trash'' are allowed';
	END IF;
	
	IF id = id_verified THEN
    UPDATE mail.message m
		SET body = mail.jsonb_merge((SELECT body FROM mail.message m2 WHERE m2.id = id_verified), jsonb_build_object(identity, properties))
		WHERE m.id = id_verified
		RETURNING m.id INTO id;
  ELSE
  	id = NULL;
	END IF;
END
$_$;


--
-- TOC entry 204 (class 1259 OID 16518)
-- Name: message_id_seq; Type: SEQUENCE; Schema: mail; Owner: -
--

CREATE SEQUENCE mail.message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 205 (class 1259 OID 16520)
-- Name: message; Type: TABLE; Schema: mail; Owner: -
--

CREATE TABLE mail.message (
    id bigint DEFAULT nextval('mail.message_id_seq'::regclass) NOT NULL,
    body jsonb NOT NULL,
    search_from tsvector,
    search_to tsvector,
    search_cc tsvector,
    search_bcc tsvector,
    search_subject tsvector,
    search_body tsvector,
    search_attachment_name tsvector,
    search_attachment_content tsvector,
    search_tag_name tsvector,
    search_tag_value tsvector,
    search_label tsvector,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);


--
-- TOC entry 2861 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.id; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.id IS 'The document primary key. Will be added to the body when retrieved using Massive document functions';


--
-- TOC entry 2862 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.body; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.body IS 'The document body, stored without primary key.';


--
-- TOC entry 2863 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.search_from; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.search_from IS 'Search vector for full-text search support.';


--
-- TOC entry 2864 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.search_to; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.search_to IS 'Search vector for full-text search support.';
COMMENT ON COLUMN mail.message.search_cc IS 'Search vector for full-text search support.';
COMMENT ON COLUMN mail.message.search_bcc IS 'Search vector for full-text search support.';


--
-- TOC entry 2865 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.search_subject; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.search_subject IS 'Search vector for full-text search support.';


--
-- TOC entry 2866 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.search_body; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.search_body IS 'Search vector for full-text search support.';


--
-- TOC entry 2867 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.search_attachment_name; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.search_attachment_name IS 'Search vector for full-text search support.';


--
-- TOC entry 2868 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.search_attachment_content; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.search_attachment_content IS 'Search vector for full-text search support.';


--
-- TOC entry 2869 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.search_tag; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.search_tag_name IS 'Search vector for full-text search support.';

COMMENT ON COLUMN mail.message.search_tag_value IS 'Search vector for full-text search support.';


--
-- TOC entry 2870 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.search_label; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.search_label IS 'Search vector for full-text search support.';


--
-- TOC entry 2871 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN message.created_at; Type: COMMENT; Schema: mail; Owner: -
--

COMMENT ON COLUMN mail.message.created_at IS 'Timestamp for the record''s last modification.';


--
-- TOC entry 2732 (class 2606 OID 16549)
-- Name: message message_pkey; Type: CONSTRAINT; Schema: mail; Owner: -
--

ALTER TABLE ONLY mail.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- TOC entry 2722 (class 1259 OID 16537)
-- Name: idx_message_body; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_message_body ON mail.message USING gin (body jsonb_path_ops);


--
-- TOC entry 2723 (class 1259 OID 16543)
-- Name: idx_search_message_attachment_content; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_search_message_attachment_content ON mail.message USING gin (search_attachment_content);


--
-- TOC entry 2724 (class 1259 OID 16542)
-- Name: idx_search_message_attachment_name; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_search_message_attachment_name ON mail.message USING gin (search_attachment_name);


--
-- TOC entry 2725 (class 1259 OID 16541)
-- Name: idx_search_message_body; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_search_message_body ON mail.message USING gin (search_body);


--
-- TOC entry 2726 (class 1259 OID 16538)
-- Name: idx_search_message_from; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_search_message_from ON mail.message USING gin (search_from);


--
-- TOC entry 2727 (class 1259 OID 16545)
-- Name: idx_search_message_label; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_search_message_label ON mail.message USING gin (search_label);


--
-- TOC entry 2728 (class 1259 OID 16540)
-- Name: idx_search_message_subject; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_search_message_subject ON mail.message USING gin (search_subject);


--
-- TOC entry 2729 (class 1259 OID 16544)
-- Name: idx_search_message_tag; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_search_message_tag_name ON mail.message USING gin (search_tag_name);

CREATE INDEX idx_search_message_tag_value ON mail.message USING gin (search_tag_value);


--
-- TOC entry 2730 (class 1259 OID 16539)
-- Name: idx_search_message_to; Type: INDEX; Schema: mail; Owner: -
--

CREATE INDEX idx_search_message_to ON mail.message USING gin (search_to);
CREATE INDEX idx_search_message_cc ON mail.message USING gin (search_cc);
CREATE INDEX idx_search_message_bcc ON mail.message USING gin (search_bcc);


--
-- TOC entry 2733 (class 2620 OID 16546)
-- Name: message mail_message_inserted; Type: TRIGGER; Schema: mail; Owner: -
--

CREATE TRIGGER mail_message_inserted BEFORE INSERT ON mail.message FOR EACH ROW EXECUTE PROCEDURE mail.message_table_inserted();


--
-- TOC entry 2734 (class 2620 OID 16547)
-- Name: message mail_message_updated; Type: TRIGGER; Schema: mail; Owner: -
--

CREATE TRIGGER mail_message_updated BEFORE UPDATE ON mail.message FOR EACH ROW EXECUTE PROCEDURE mail.message_table_updated();


-- Completed on 2018-11-30 10:27:58

--
-- PostgreSQL database dump complete
--

