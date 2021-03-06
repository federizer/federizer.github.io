DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
   
CREATE EXTENSION "pgcrypto" WITH SCHEMA public;

DROP SCHEMA mail CASCADE;
CREATE SCHEMA mail;

CREATE TYPE mail.actions AS ENUM ('send', 'reply', 'forward');   


CREATE SEQUENCE mail.email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
   
CREATE SEQUENCE mail.timeline_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;   

CREATE TABLE mail.message (
    id bigint DEFAULT nextval('mail.email_id_seq'::regclass) NOT NULL,
    uumid uuid NOT NULL DEFAULT public.gen_random_uuid(), -- universally unique message identifier
    uupmid uuid,										-- universally unique parent message identifier
    uumtid uuid,										-- universally unique message thread identifier
    fwd bool NOT NULL DEFAULT false,					-- forwarded
    sender_email_address character varying(255) NOT NULL,
    sender_display_name character varying(1024),
    subject text,
    body text,
    sent_at timestamp(6) with time zone,
    sender_timeline_id bigint DEFAULT nextval('mail.timeline_id_seq'::regclass) NOT NULL,
    search_from tsvector,
    search_subject tsvector,
    search_body tsvector,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone,
    deleted_at_sender bool NOT NULL DEFAULT false
);

DROP SCHEMA postal CASCADE;
CREATE SCHEMA postal;

CREATE TYPE postal.mailbox_folders AS ENUM ('inbox', 'snoozed', 'sent', 'drafts');   
CREATE TYPE postal.mailbox_labels AS ENUM ('done', 'archived', 'starred', 'important', 'chats', 'spam', 'unread', 'trash');

CREATE TABLE postal.mailbox (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    message_id bigint,
    envelope_id bigint,
    folder postal.mailbox_folders NOT NULL DEFAULT 'inbox',
    done bool NOT NULL DEFAULT false,
    archived bool NOT NULL DEFAULT false,
    starred bool NOT NULL DEFAULT false,
    important bool NOT NULL DEFAULT false,
    chats bool NOT NULL DEFAULT false,
    spam bool NOT NULL DEFAULT false,
    unread bool NOT NULL DEFAULT false,
    trash bool NOT NULL DEFAULT false
);

CREATE TYPE mail.envelope_type AS ENUM ('to', 'cc', 'bcc');      

CREATE TABLE mail.envelope (
    id bigint DEFAULT nextval('mail.email_id_seq'::regclass) NOT NULL,
    message_id bigint NOT NULL,
    type mail.envelope_type NOT NULL DEFAULT 'to',
    recipient_email_address character varying(255) NOT NULL,
    recipient_display_name character varying(1024),
    received_at timestamp(6) with time zone,
    snoozed_at timestamp(6) with time zone,
    recipient_timeline_id bigint DEFAULT nextval('mail.timeline_id_seq'::regclass) NOT NULL,
    search_to tsvector,
    search_cc tsvector,
    search_bcc tsvector,
    created_at timestamp(6) with time zone DEFAULT now(),
    deleted_at_recipient bool NOT NULL DEFAULT false
);

CREATE TABLE mail.attachment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    message_id bigint NOT NULL,
    uuaid uuid NOT NULL,
    filename character varying(255) NOT NULL,
    destination character varying(4096) NOT NULL,
    mimetype character varying(255) NOT NULL,
    encoding character varying(255) NOT NULL,
    size bigint NOT NULL,
    content text,
    search_filename tsvector,
    search_content tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE TABLE mail.tag (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    message_id bigint NOT NULL,
    type smallint DEFAULT 0 NOT NULL,
    name character varying(255) NOT NULL,
    value character varying(255),
    search_name tsvector,
    search_value tsvector,
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
	  	NEW.sender_timeline_id := nextval('mail.timeline_id_seq'::regclass);
	
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
		NEW.search_filename = to_tsvector(NEW.filename);
		NEW.search_content = to_tsvector(search_content);
	
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

CREATE FUNCTION mail.envelope_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	BEGIN
		IF NEW.recipient_email_address <> OLD.recipient_email_address OR
		   NEW.recipient_display_name <> OLD.recipient_display_name THEN
        	RAISE EXCEPTION 'update not allowed' USING hint = 'Changes to recipient email address or display name are not allowed.';
       END IF;

        NEW.recipient_timeline_id := nextval('mail.timeline_id_seq'::regclass);
	
	    RETURN NEW; 
	END; $$;

CREATE OR REPLACE FUNCTION mail.prevent_update()
  RETURNS trigger AS
$BODY$
    BEGIN
        RAISE EXCEPTION 'update not allowed';
        RETURN NULL;
    END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
 
ALTER TABLE ONLY mail.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);

ALTER TABLE ONLY mail.envelope
    ADD CONSTRAINT envelope_pkey PRIMARY KEY (id);
 
ALTER TABLE ONLY mail.message
    ADD CONSTRAINT message_sender_timeline_unique UNIQUE (sender_timeline_id);
   
ALTER TABLE ONLY mail.message
    ADD CONSTRAINT message_id_sender_unique UNIQUE (id, sender_email_address);
   
ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_id_owner_unique UNIQUE (id, owner);

ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_message_id_unique UNIQUE (message_id, owner);

ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_envelope_id_unique UNIQUE (envelope_id, owner);

ALTER TABLE ONLY mail.envelope
    ADD CONSTRAINT envelope_id_message_id_unique UNIQUE (id, recipient_email_address),
    ADD CONSTRAINT envelope_recipient_address_message_id_unique UNIQUE (recipient_email_address, message_id);  -- comment out to enable duplicate recipients

ALTER TABLE ONLY mail.envelope
    ADD CONSTRAINT envelope_recipient_timeline_unique UNIQUE (recipient_timeline_id);
   
ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_message_id_message_fkey FOREIGN KEY (message_id, owner) REFERENCES mail.message(id, sender_email_address) ON DELETE CASCADE,
    ADD CONSTRAINT mailbox_envelope_id_envelope_fkey FOREIGN KEY (envelope_id, owner) REFERENCES mail.envelope(id, recipient_email_address) ON DELETE CASCADE,
	ADD CONSTRAINT message_id_xor_envelope_id CHECK ((message_id IS NULL) != (envelope_id IS NULL)),
	ADD CONSTRAINT mailbox_valid_folders CHECK ((message_id IS NOT NULL AND folder IN ('sent'::postal.mailbox_folders, 'drafts'::postal.mailbox_folders)) OR
													(envelope_id IS NOT NULL AND folder IN ('inbox'::postal.mailbox_folders, 'snoozed'::postal.mailbox_folders)));

ALTER TABLE ONLY mail.envelope
    ADD CONSTRAINT envelope_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id) ON DELETE CASCADE;   

ALTER TABLE ONLY mail.attachment
    ADD CONSTRAINT attachment_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id) ON DELETE CASCADE;

ALTER TABLE ONLY mail.tag
    ADD CONSTRAINT tag_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id) ON DELETE CASCADE;
   
CREATE INDEX idx_search_message_from ON mail.message USING gin (search_from);
CREATE INDEX idx_search_message_subject ON mail.message USING gin (search_subject);
CREATE INDEX idx_search_message_body ON mail.message USING gin (search_body);
CREATE INDEX idx_search_attachment_name ON mail.attachment USING gin (search_filename);
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
CREATE TRIGGER mail_envelope_updated BEFORE UPDATE ON mail.envelope FOR EACH ROW EXECUTE PROCEDURE mail.envelope_table_updated();

CREATE TRIGGER mail_prevent_update BEFORE UPDATE ON mail.attachment FOR EACH ROW EXECUTE PROCEDURE mail.prevent_update();
CREATE TRIGGER mail_prevent_update BEFORE UPDATE ON mail.tag FOR EACH ROW EXECUTE PROCEDURE mail.prevent_update();
