/*
 Navicat Premium Data Transfer

 Source Server         : do-frankfurt-repo
 Source Server Type    : PostgreSQL
 Source Server Version : 100004
 Source Host           : 127.0.0.1:6432
 Source Catalog        : dps-repository
 Source Schema         : postal

 Target Server Type    : PostgreSQL
 Target Server Version : 100004
 File Encoding         : 65001

 Date: 25/09/2018 11:03:06
*/


-- ----------------------------
-- Sequence structure for messages_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "postal"."messages_id_seq";
CREATE SEQUENCE "postal"."messages_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 9223372036854775807
START 1
CACHE 1;

-- ----------------------------
-- Table structure for messages
-- ----------------------------
DROP TABLE IF EXISTS "postal"."messages";
CREATE TABLE "postal"."messages" (
  "id" int8 NOT NULL DEFAULT nextval('"postal".messages_id_seq'::regclass),
  "body" jsonb NOT NULL,
  "search" tsvector,
  "created_at" timestamptz(6) DEFAULT now(),
  "updated_at" timestamptz(6)
)
;
COMMENT ON COLUMN "postal"."messages"."id" IS 'The document primary key. Will be added to the body when retrieved using Massive document functions';
COMMENT ON COLUMN "postal"."messages"."body" IS 'The document body, stored without primary key.';
COMMENT ON COLUMN "postal"."messages"."search" IS 'Search vector for full-text search support.';
COMMENT ON COLUMN "postal"."messages"."created_at" IS 'Timestamp for the record''s last modification.';
COMMENT ON TABLE "postal"."messages" IS 'A document table generated with Massive.js.';

-- ----------------------------
-- Function structure for create_fw_message
-- ----------------------------
DROP FUNCTION IF EXISTS "postal"."create_fw_message"(IN "old_id" int8, IN "identity" varchar, IN "folder" varchar, OUT "id" int8, OUT "body" jsonb);
CREATE OR REPLACE FUNCTION "postal"."create_fw_message"(IN "old_id" int8, IN "identity" varchar, IN "folder" varchar, OUT "id" int8, OUT "body" jsonb)
  RETURNS "pg_catalog"."record" AS $BODY$
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
	FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter AND m.body ? 'sent_at'
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
		INSERT INTO postal.messages(body)
		VALUES(new_body)
		RETURNING postal.messages.id, postal.messages.body INTO create_fw_message.id, create_fw_message.body;
  END IF;
ELSIF folder = 'sent' THEN
	folder_filter = '{"sender": {"email_address": "' || $2 || '"}}';
	RAISE NOTICE 'folder_filter for ''sent'' %',folder_filter;

	INSERT INTO postal.messages(body)
	SELECT
	 jsonb_build_object('sender', m.body->'sender') ||
	 jsonb_build_object('subject', m.body->'subject') ||
	 jsonb_build_object('body', m.body->'body') ||
	 jsonb_build_object('attachments', m.body->'attachments')
	FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter AND m.body ? 'sent_at'
	AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
	RETURNING postal.messages.id, postal.messages.body INTO create_fw_message.id, create_fw_message.body;
ELSE
  RAISE EXCEPTION 'Unsupported folder: %', folder USING HINT = 'Only ''inbox'' or ''sent'' are allowed';
END IF;

end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for create_re_message
-- ----------------------------
DROP FUNCTION IF EXISTS "postal"."create_re_message"(IN "old_id" int8, IN "identity" varchar, IN "folder" varchar, OUT "id" int8, OUT "body" jsonb);
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
	 jsonb_build_object('subject', m.body->'subject') ||
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
  COST 100;

-- ----------------------------
-- Function structure for jsonb_merge
-- ----------------------------
DROP FUNCTION IF EXISTS "postal"."jsonb_merge"("a" jsonb, "b" jsonb);
CREATE OR REPLACE FUNCTION "postal"."jsonb_merge"("a" jsonb, "b" jsonb)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
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
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for jsonb_merge_deep
-- ----------------------------
DROP FUNCTION IF EXISTS "postal"."jsonb_merge_deep"(jsonb, jsonb);
CREATE OR REPLACE FUNCTION "postal"."jsonb_merge_deep"(jsonb, jsonb)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
  select case jsonb_typeof($1)
    when 'object' then case jsonb_typeof($2)
      when 'object' then (
        select    jsonb_object_agg(k, case
                    when e2.v is null then e1.v
                    when e1.v is null then e2.v
                    else jsonb_merge_deep(e1.v, e2.v)
                  end)
        from      jsonb_each($1) e1(k, v)
        full join jsonb_each($2) e2(k, v) using (k)
      )
      else $2
    end
    when 'array' then $1 || $2
    else $2
  end
$BODY$
  LANGUAGE sql IMMUTABLE
  COST 100;

-- ----------------------------
-- Function structure for jsonb_recursive_merge
-- ----------------------------
DROP FUNCTION IF EXISTS "postal"."jsonb_recursive_merge"("a" jsonb, "b" jsonb);
CREATE OR REPLACE FUNCTION "postal"."jsonb_recursive_merge"("a" jsonb, "b" jsonb)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
select
    jsonb_object_agg(
        coalesce(ka, kb),
        case
            when va isnull then vb
            when vb isnull then va
            when jsonb_typeof(va) <> 'object' or jsonb_typeof(vb) <> 'object' then vb
            else postal.jsonb_recursive_merge(va, vb) end
        )
    from jsonb_each(a) e1(ka, va)
    full join jsonb_each(b) e2(kb, vb) on ka = kb
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for massive_document_inserted
-- ----------------------------
DROP FUNCTION IF EXISTS "postal"."massive_document_inserted"();
CREATE OR REPLACE FUNCTION "postal"."massive_document_inserted"()
  RETURNS "pg_catalog"."trigger" AS $BODY$ BEGIN NEW.search = to_tsvector(NEW.body::text); RETURN NEW; END; $BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER
  COST 100;

-- ----------------------------
-- Function structure for massive_document_updated
-- ----------------------------
DROP FUNCTION IF EXISTS "postal"."massive_document_updated"();
CREATE OR REPLACE FUNCTION "postal"."massive_document_updated"()
  RETURNS "pg_catalog"."trigger" AS $BODY$ BEGIN NEW.updated_at = now(); NEW.search = to_tsvector(NEW.body::text); RETURN NEW; END; $BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER
  COST 100;

-- ----------------------------
-- Function structure for set_properties
-- ----------------------------
DROP FUNCTION IF EXISTS "postal"."set_properties"(INOUT "id" int8, IN "identity" varchar, IN "folder" varchar, IN "properties" jsonb);
CREATE OR REPLACE FUNCTION "postal"."set_properties"(INOUT "id" int8, IN "identity" varchar, IN "folder" varchar, IN "properties" jsonb)
  RETURNS "pg_catalog"."int8" AS $BODY$
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
		FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter_recipient AND m.body ? 'sent_at'
		AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
		INTO id_verified;
	ELSIF folder = 'sent' THEN
		SELECT m.id
		FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter_sender AND m.body ? 'sent_at'
		AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
		INTO id_verified;
  ELSIF folder = 'draft' THEN
		SELECT m.id
		FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter_sender AND NOT m.body ? 'sent_at'
		AND NOT (m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb) OR m.body @> jsonb_build_object($2, '{"trash": 2}'::jsonb))
		INTO id_verified;
	ELSIF folder = 'trash' THEN
	  -- inbox
		SELECT m.id
		FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter_recipient AND m.body ? 'sent_at'
		AND m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb)
		INTO id_verified;
	  
		IF id_verified IS NULL THEN
  	  -- sent
			SELECT m.id
			FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter_sender AND m.body ? 'sent_at'
  		AND m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb)
			INTO id_verified;
			
  		IF id_verified IS NULL THEN
    	  -- draft
				SELECT m.id
				FROM postal.messages m WHERE m.id = $1 AND m.body @> folder_filter_sender AND NOT m.body ? 'sent_at'
    		AND m.body @> jsonb_build_object($2, '{"trash": 1}'::jsonb)
				INTO id_verified;
			END IF;
		END IF;		
	ELSE
		RAISE EXCEPTION 'Unsupported folder: %', folder USING HINT = 'Only ''inbox'', ''sent'' , ''draft''  or ''trash'' are allowed';
	END IF;
	
	IF id = id_verified THEN
    UPDATE postal.messages m
		SET body = postal.jsonb_merge((SELECT body FROM postal.messages m2 WHERE m2.id = id_verified), jsonb_build_object(identity, properties))
		WHERE m.id = id_verified
		RETURNING m.id INTO id;
  ELSE
  	id = NULL;
	END IF;
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
SELECT setval('"postal"."messages_id_seq"', 13, true);

-- ----------------------------
-- Indexes structure for table messages
-- ----------------------------
CREATE INDEX "idx_messages" ON "postal"."messages" USING gin (
  "body" "pg_catalog"."jsonb_path_ops"
);
CREATE INDEX "idx_search_messages" ON "postal"."messages" USING gin (
  "search" "pg_catalog"."tsvector_ops"
);

-- ----------------------------
-- Triggers structure for table messages
-- ----------------------------
CREATE TRIGGER "public_messages_inserted" BEFORE INSERT ON "postal"."messages"
FOR EACH ROW
EXECUTE PROCEDURE "postal"."massive_document_inserted"();
CREATE TRIGGER "public_messages_updated" BEFORE UPDATE ON "postal"."messages"
FOR EACH ROW
EXECUTE PROCEDURE "postal"."massive_document_updated"();

-- ----------------------------
-- Primary Key structure for table messages
-- ----------------------------
ALTER TABLE "postal"."messages" ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");
