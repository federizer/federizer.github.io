/*DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
   
CREATE EXTENSION "pgcrypto" WITH SCHEMA public;*/

DROP SCHEMA email CASCADE;
CREATE SCHEMA email;

CREATE TYPE email.actions AS ENUM ('send', 'reply', 'forward');   


CREATE SEQUENCE email.email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
   
CREATE SEQUENCE email.timeline_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;   

CREATE TABLE email.message (
    id bigint DEFAULT nextval('email.email_id_seq'::regclass) NOT NULL,
    uumid uuid NOT NULL DEFAULT public.gen_random_uuid(), 	-- universally unique message identifier
    uupmid uuid,											-- universally unique parent message identifier
    uumtid uuid,											-- universally unique message thread identifier
    fwd bool NOT NULL DEFAULT false,						-- forwarded
    sender_email_address character varying(255) NOT NULL,
    sender_display_name character varying(1024),
    subject text,
    body text,
    sent_at timestamp(6) with time zone,
    sender_timeline_id bigint DEFAULT nextval('email.timeline_id_seq'::regclass) NOT NULL,
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

CREATE TYPE email.envelope_type AS ENUM ('to', 'cc', 'bcc');      

CREATE TABLE email.envelope (
    id bigint DEFAULT nextval('email.email_id_seq'::regclass) NOT NULL,
    message_id bigint NOT NULL,
    type email.envelope_type NOT NULL DEFAULT 'to',
    recipient_email_address character varying(255) NOT NULL,
    recipient_display_name character varying(1024),
    received_at timestamp(6) with time zone,
    snoozed_at timestamp(6) with time zone,
    recipient_timeline_id bigint DEFAULT nextval('email.timeline_id_seq'::regclass) NOT NULL,
    search_to tsvector,
    search_cc tsvector,
    search_bcc tsvector,
    created_at timestamp(6) with time zone DEFAULT now(),
    deleted_at_recipient bool NOT NULL DEFAULT false
);

CREATE TABLE email.attachment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    uuaid uuid NOT NULL DEFAULT public.gen_random_uuid(), 	-- universally unique attachment identifier
    filename character varying(255) NOT NULL,
    mimetype character varying(255) NOT NULL,
    encoding character varying(255) NOT NULL,
    search_filename tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE TABLE email.attachment_content (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    uuacid uuid NOT NULL, 									-- universally unique attachment content identifier
    attachment_id bigint NOT NULL,
    version_major int4 NOT NULL DEFAULT 1,
    version_minor int4 NOT NULL DEFAULT 1,
    destination character varying(4096) NOT NULL,
    size bigint NOT NULL,
    content text,
    search_content tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE TABLE email.has (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    message_id bigint NOT NULL,
    attachment_id bigint NOT NULL,
    attachment_content_id bigint NOT NULL
);

CREATE TABLE email.tag (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    message_id bigint NOT NULL,
    type smallint DEFAULT 0 NOT NULL,
    name character varying(255) NOT NULL,
    value character varying(255),
    search_name tsvector,
    search_value tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE FUNCTION email.message_table_inserted() RETURNS trigger
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

CREATE FUNCTION email.message_table_updated() RETURNS trigger
	LANGUAGE plpgsql SECURITY DEFINER
	AS $$ 
	DECLARE
	search_body text;
	BEGIN
	  	NEW.updated_at = now();
	  	NEW.sender_timeline_id := nextval('email.timeline_id_seq'::regclass);
	
		--search_body = regexp_replace(regexp_replace(NEW.body, E'(?x)<[^>]*?(\s alt \s* = \s* ([\'"]) ([^>]*?) \2) [^>]*? >', E'\3'), E'(?x)(< [^>]*? >)', '', 'g');
		search_body = regexp_replace(NEW.body, E'<[^>]+>', '', 'gi');
	
		NEW.search_from = to_tsvector(NEW.sender_email_address ||	', ' ||	NEW.sender_display_name);
		NEW.search_subject = to_tsvector(NEW.subject);
		NEW.search_body = to_tsvector(search_body);
	
	    RETURN NEW; 
	
	END; $$;

CREATE FUNCTION email.attachment_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	BEGIN				
		NEW.search_filename = to_tsvector(NEW.filename);
	
		RETURN NEW;	
	END; $$;

CREATE FUNCTION email.attachment_content_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	DECLARE
	search_content text;
	BEGIN				
		NEW.search_content = to_tsvector(search_content);
	
		RETURN NEW;	
	END; $$;

CREATE FUNCTION email.tag_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	BEGIN				
		NEW.search_name = to_tsvector(NEW.name);
		NEW.search_value = to_tsvector(NEW.value);
	
		RETURN NEW;	
	END; $$;

CREATE FUNCTION email.envelope_table_inserted() RETURNS trigger
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

CREATE FUNCTION email.envelope_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	BEGIN
		IF NEW.recipient_email_address <> OLD.recipient_email_address OR
		   NEW.recipient_display_name <> OLD.recipient_display_name THEN
        	RAISE EXCEPTION 'update not allowed' USING hint = 'Changes to recipient email address or display name are not allowed.';
        END IF;

        NEW.recipient_timeline_id := nextval('email.timeline_id_seq'::regclass);
	
	    RETURN NEW; 
	END; $$;

CREATE OR REPLACE FUNCTION email.prevent_update() RETURNS trigger AS
$BODY$
    BEGIN
        RAISE EXCEPTION 'update not allowed';
        RETURN NULL;
    END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
 
ALTER TABLE ONLY email.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);

ALTER TABLE ONLY email.envelope
    ADD CONSTRAINT envelope_pkey PRIMARY KEY (id);
 
ALTER TABLE ONLY email.message
    ADD CONSTRAINT message_sender_timeline_unique UNIQUE (sender_timeline_id);
   
ALTER TABLE ONLY email.message
    ADD CONSTRAINT message_id_sender_unique UNIQUE (id, sender_email_address);
   
ALTER TABLE ONLY email.attachment
    ADD CONSTRAINT attachment_id_owner_unique UNIQUE (id, owner);

ALTER TABLE ONLY email.attachment_content
    ADD CONSTRAINT attachment_content_id_attachment_id_unique UNIQUE (id, attachment_id),
    ADD CONSTRAINT attachment_content_versions_unique UNIQUE (version_major, version_minor);

ALTER TABLE ONLY email.has
    ADD CONSTRAINT has_message_attachment_unique UNIQUE (owner, message_id, attachment_id);    

ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_id_owner_unique UNIQUE (id, owner);

ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_message_id_unique UNIQUE (message_id, owner);

ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_envelope_id_unique UNIQUE (envelope_id, owner);
   
ALTER TABLE ONLY email.envelope
    ADD CONSTRAINT envelope_id_message_id_unique UNIQUE (id, recipient_email_address),
    ADD CONSTRAINT envelope_recipient_address_message_id_unique UNIQUE (recipient_email_address, message_id);  -- comment out to enable duplicate recipients

ALTER TABLE ONLY email.envelope
    ADD CONSTRAINT envelope_recipient_timeline_unique UNIQUE (recipient_timeline_id);
   
ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_message_id_message_fkey FOREIGN KEY (message_id, owner) REFERENCES email.message(id, sender_email_address) ON DELETE CASCADE,
    ADD CONSTRAINT mailbox_envelope_id_envelope_fkey FOREIGN KEY (envelope_id, owner) REFERENCES email.envelope(id, recipient_email_address) ON DELETE CASCADE,
	ADD CONSTRAINT message_id_xor_envelope_id CHECK ((message_id IS NULL) != (envelope_id IS NULL)),
	ADD CONSTRAINT mailbox_valid_folders CHECK ((message_id IS NOT NULL AND folder IN ('sent'::postal.mailbox_folders, 'drafts'::postal.mailbox_folders)) OR
													(envelope_id IS NOT NULL AND folder IN ('inbox'::postal.mailbox_folders, 'snoozed'::postal.mailbox_folders)));

ALTER TABLE ONLY email.envelope
    ADD CONSTRAINT envelope_message_fkey FOREIGN KEY (message_id) REFERENCES email.message(id) ON DELETE CASCADE;   

ALTER TABLE ONLY email.attachment_content
    ADD CONSTRAINT attachment_content_attachment_id_attachment_fkey FOREIGN KEY (attachment_id) REFERENCES email.attachment(id) ON DELETE CASCADE;

ALTER TABLE ONLY email.has
    ADD CONSTRAINT has_message_id_owner_fkey FOREIGN KEY (message_id, owner) REFERENCES email.message(id, sender_email_address) ON DELETE CASCADE,
    ADD CONSTRAINT has_attachment_id_owner_fkey FOREIGN KEY (attachment_id, owner) REFERENCES email.attachment(id, owner), --ON DELETE CASCADE
    ADD CONSTRAINT has_attachment_content_id_fkey FOREIGN KEY (attachment_content_id, attachment_id) REFERENCES email.attachment_content(id, attachment_id); --ON DELETE CASCADE

ALTER TABLE ONLY email.tag
    ADD CONSTRAINT tag_message_fkey FOREIGN KEY (message_id) REFERENCES email.message(id) ON DELETE CASCADE;
   
CREATE INDEX idx_search_message_from ON email.message USING gin (search_from);
CREATE INDEX idx_search_message_subject ON email.message USING gin (search_subject);
CREATE INDEX idx_search_message_body ON email.message USING gin (search_body);
CREATE INDEX idx_search_attachment_filename ON email.attachment USING gin (search_filename);
CREATE INDEX idx_search_attachment_content ON email.attachment_content USING gin (search_content);
CREATE INDEX idx_search_tag_name ON email.tag USING gin (search_name);
CREATE INDEX idx_search_tag_value ON email.tag USING gin (search_value);
CREATE INDEX idx_search_envelope_to ON email.envelope USING gin (search_to);
CREATE INDEX idx_search_envelope_cc ON email.envelope USING gin (search_cc);
CREATE INDEX idx_search_envelope_bcc ON email.envelope USING gin (search_bcc);

CREATE TRIGGER email_message_inserted BEFORE INSERT ON email.message FOR EACH ROW EXECUTE PROCEDURE email.message_table_inserted();
CREATE TRIGGER email_message_updated BEFORE UPDATE ON email.message FOR EACH ROW EXECUTE PROCEDURE email.message_table_updated();
CREATE TRIGGER email_attachment_inserted BEFORE INSERT ON email.attachment FOR EACH ROW EXECUTE PROCEDURE email.attachment_table_inserted();
CREATE TRIGGER email_attachment_content_inserted BEFORE INSERT ON email.attachment_content FOR EACH ROW EXECUTE PROCEDURE email.attachment_content_table_inserted();
CREATE TRIGGER email_tag_inserted BEFORE INSERT ON email.tag FOR EACH ROW EXECUTE PROCEDURE email.tag_table_inserted();
CREATE TRIGGER email_envelope_inserted BEFORE INSERT ON email.envelope FOR EACH ROW EXECUTE PROCEDURE email.envelope_table_inserted();
CREATE TRIGGER email_envelope_updated BEFORE UPDATE ON email.envelope FOR EACH ROW EXECUTE PROCEDURE email.envelope_table_updated();

CREATE TRIGGER email_prevent_update BEFORE UPDATE ON email.attachment FOR EACH ROW EXECUTE PROCEDURE email.prevent_update();
CREATE TRIGGER email_prevent_update BEFORE UPDATE ON email.attachment_content FOR EACH ROW EXECUTE PROCEDURE email.prevent_update();
CREATE TRIGGER email_prevent_update BEFORE UPDATE ON email.tag FOR EACH ROW EXECUTE PROCEDURE email.prevent_update();
