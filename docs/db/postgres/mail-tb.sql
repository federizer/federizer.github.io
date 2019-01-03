CREATE SCHEMA mail;

CREATE SEQUENCE mail.message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE mail.message (
    id bigint DEFAULT nextval('mail.message_id_seq'::regclass) NOT NULL,
    sender_email_address character varying(255) NOT NULL,
    sender_display_name character varying(1024),
    subject text,
    body text,
    search_from tsvector,
    search_subject tsvector,
    search_body tsvector,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

CREATE SEQUENCE mail.attachment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE mail.attachment (
    id bigint DEFAULT nextval('mail.attachment_id_seq'::regclass) NOT NULL,
    message_id bigint NOT NULL,
    destination character varying(4096) NOT NULL,
    filename character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    mimetype character varying(255) NOT NULL,
    encoding character varying(255) NOT NULL,
    size bigint NOT NULL,
    content text,
    search_name tsvector,
    search_content tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE SEQUENCE mail.tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE mail.tag (
    id bigint DEFAULT nextval('mail.tag_id_seq'::regclass) NOT NULL,
    message_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    value character varying(255),
    search_name tsvector,
    search_value tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE SEQUENCE mail.envelope_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
   
CREATE TYPE mail.envelope_type AS ENUM ('to', 'cc', 'bcc');      

CREATE TABLE mail.envelope (
    id bigint DEFAULT nextval('mail.envelope_id_seq'::regclass) NOT NULL,
    message_id bigint NOT NULL,
    type mail.envelope_type NOT NULL DEFAULT 'to',
    recipient_email_address character varying(255) NOT NULL,
    recipient_display_name character varying(1024),
    search_to tsvector,
    search_cc tsvector,
    search_bcc tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE FUNCTION mail.message_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	DECLARE
	search_body text;
	BEGIN				
		--search_body = regexp_replace(regexp_replace(NEW.body, E'(?x)<[^>]*?(\s alt \s* = \s* ([\'"]) ([^>]*?) \2) [^>]*? >', E'\3'), E'(?x)(< [^>]*? >)', '', 'g');
		search_body = regexp_replace(NEW.body, E'<[^>]+>', '', 'gi');
	
		NEW.search_from = to_tsvector(NEW.sender_email_address ||	', ' ||	NEW.sender_display_name);
		NEW.search_subject = to_tsvector(NEW.subject);
		NEW.search_body = to_tsvector(search_body);
	
		RETURN NEW;	
	END; $$;

CREATE FUNCTION mail.message_table_updated() RETURNS trigger
	LANGUAGE plpgsql SECURITY DEFINER
	AS $$ 
	DECLARE
	search_body text;
	BEGIN
	  	NEW.updated_at = now();
	
		--search_body = regexp_replace(regexp_replace(NEW.body, E'(?x)<[^>]*?(\s alt \s* = \s* ([\'"]) ([^>]*?) \2) [^>]*? >', E'\3'), E'(?x)(< [^>]*? >)', '', 'g');
		search_body = regexp_replace(NEW.body, E'<[^>]+>', '', 'gi');
	
		NEW.search_from = to_tsvector(NEW.sender_email_address ||	', ' ||	NEW.sender_display_name);
		NEW.search_subject = to_tsvector(NEW.subject);
		NEW.search_body = to_tsvector(search_body);
	
	    RETURN NEW; 
	
	END; $$;

CREATE FUNCTION mail.attachment_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	DECLARE
	search_content text;
	BEGIN				
		NEW.search_name = to_tsvector(NEW.name);
		--NEW.search_content = to_tsvector(search_content);
	
		RETURN NEW;	
	END; $$;

CREATE FUNCTION mail.tag_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	BEGIN				
		NEW.search_name = to_tsvector(NEW.name);
		NEW.search_value = to_tsvector(NEW.value);
	
		RETURN NEW;	
	END; $$;

CREATE FUNCTION mail.envelope_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	DECLARE
	recipient_data text;
	begin
		recipient_data = NEW.recipient_email_address ||	', ' ||	NEW.recipient_display_name;
		if NEW.type = 'to' then
			NEW.search_to = to_tsvector(recipient_data);
		elsif NEW.type = 'cc' then
			NEW.search_cc = to_tsvector(recipient_data);
		elsif NEW.type = 'bcc' then
			NEW.search_bcc = to_tsvector(recipient_data);
		end if;
	
		RETURN NEW;	
	END; $$;

CREATE OR REPLACE FUNCTION mail.prevent_update()
  RETURNS trigger AS
$BODY$
    BEGIN
        RAISE EXCEPTION 'update not allowed';
    END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

ALTER TABLE ONLY mail.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);

ALTER TABLE ONLY mail.attachment
    ADD CONSTRAINT attachment_pkey PRIMARY KEY (id);

ALTER TABLE ONLY mail.tag
    ADD CONSTRAINT tag_pkey PRIMARY KEY (id);

ALTER TABLE ONLY mail.envelope
    ADD CONSTRAINT envelope_pkey PRIMARY KEY (id);

ALTER TABLE ONLY mail.attachment
    ADD CONSTRAINT attachment_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id);

ALTER TABLE ONLY mail.tag
    ADD CONSTRAINT tag_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id);

ALTER TABLE ONLY mail.envelope
    ADD CONSTRAINT envelope_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id);

CREATE INDEX idx_search_message_from ON mail.message USING gin (search_from);
CREATE INDEX idx_search_message_subject ON mail.message USING gin (search_subject);
CREATE INDEX idx_search_message_body ON mail.message USING gin (search_body);
CREATE INDEX idx_search_attachment_name ON mail.attachment USING gin (search_name);
CREATE INDEX idx_search_attachment_body ON mail.attachment USING gin (search_content);
CREATE INDEX idx_search_tag_name ON mail.tag USING gin (search_name);
CREATE INDEX idx_search_tag_value ON mail.tag USING gin (search_value);
CREATE INDEX idx_search_envelope_to ON mail.envelope USING gin (search_to);
CREATE INDEX idx_search_envelope_cc ON mail.envelope USING gin (search_cc);
CREATE INDEX idx_search_envelope_bcc ON mail.envelope USING gin (search_bcc);

CREATE TRIGGER mail_message_inserted BEFORE INSERT ON mail.message FOR EACH ROW EXECUTE PROCEDURE mail.message_table_inserted();
CREATE TRIGGER mail_message_updated BEFORE UPDATE ON mail.message FOR EACH ROW EXECUTE PROCEDURE mail.message_table_updated();
CREATE TRIGGER mail_attachment_inserted BEFORE INSERT ON mail.attachment FOR EACH ROW EXECUTE PROCEDURE mail.attachment_table_inserted();
CREATE TRIGGER mail_tag_inserted BEFORE INSERT ON mail.tag FOR EACH ROW EXECUTE PROCEDURE mail.tag_table_inserted();
CREATE TRIGGER mail_envelope_inserted BEFORE INSERT ON mail.envelope FOR EACH ROW EXECUTE PROCEDURE mail.envelope_table_inserted();

CREATE TRIGGER mail_prevent_update BEFORE UPDATE ON mail.attachment FOR EACH ROW EXECUTE PROCEDURE mail.prevent_update();
CREATE TRIGGER mail_prevent_update BEFORE UPDATE ON mail.envelope FOR EACH ROW EXECUTE PROCEDURE mail.prevent_update();
CREATE TRIGGER mail_prevent_update BEFORE UPDATE ON mail.tag FOR EACH ROW EXECUTE PROCEDURE mail.prevent_update();
