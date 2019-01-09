--
CREATE SCHEMA labels;

CREATE SEQUENCE labels.system_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
   
CREATE TYPE labels.folders AS ENUM ('inbox', 'snoozed', 'sent', 'drafts');   

CREATE TABLE labels.system_label (
    id bigint DEFAULT nextval('labels.system_label_id_seq'::regclass) NOT NULL,
    owner character varying(255) NOT NULL,
    message_id bigint NOT NULL,
    folder labels.folders NOT NULL DEFAULT 'inbox',
    done bool NOT NULL DEFAULT false,
    archived bool NOT NULL DEFAULT false,
    starred bool NOT NULL DEFAULT false,
    important bool NOT NULL DEFAULT false,
    chats bool NOT NULL DEFAULT false,
    spam bool NOT NULL DEFAULT false,
    trash bool NOT NULL DEFAULT false,
    unread bool NOT NULL DEFAULT false
);

CREATE SEQUENCE labels.has_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
   
CREATE TABLE labels.has (
    id bigint DEFAULT nextval('labels.has_id_seq'::regclass) NOT NULL,
    owner character varying(255) NOT NULL,
    message_id bigint NOT NULL,
    custom_label_id bigint NOT NULL
);

CREATE SEQUENCE labels.custom_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE labels.custom_label (
    id bigint DEFAULT nextval('labels.custom_label_id_seq'::regclass) NOT NULL,
    owner character varying(255) NOT NULL,
    custom_label_id bigint,
    filter_id bigint,
    name character varying(255) NOT NULL,
    search_name tsvector,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

ALTER TABLE ONLY labels.system_label
    ADD CONSTRAINT system_label_pkey PRIMARY KEY (id);

ALTER TABLE ONLY labels.has
    ADD CONSTRAINT has_pkey PRIMARY KEY (id);

ALTER TABLE ONLY labels.custom_label
    ADD CONSTRAINT custom_label_pkey PRIMARY KEY (id);

ALTER TABLE ONLY labels.system_label
    ADD CONSTRAINT system_label_message_unique UNIQUE (owner, message_id);

ALTER TABLE ONLY labels.has
    ADD CONSTRAINT has_message_custom_label_unique UNIQUE (owner, message_id, custom_label_id); 
   
ALTER TABLE ONLY labels.custom_label
    ADD CONSTRAINT custom_label_name_unique UNIQUE (owner, name);

ALTER TABLE ONLY labels.system_label
    ADD CONSTRAINT system_label_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id);

ALTER TABLE ONLY labels.custom_label
    ADD CONSTRAINT system_label_filter_fkey FOREIGN KEY (filter_id) REFERENCES filters.filter(id);

CREATE INDEX idx_search_custom_label_name ON labels.custom_label USING gin (search_name);

ALTER TABLE ONLY labels.has
    ADD CONSTRAINT has_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id),
    ADD CONSTRAINT has_custom_label_fkey FOREIGN KEY (custom_label_id) REFERENCES labels.custom_label(id);
   
CREATE FUNCTION labels.custom_label_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	BEGIN				
		NEW.search_name = to_tsvector(NEW.name);
	
		RETURN NEW;	
	END; $$;


CREATE FUNCTION labels.custom_label_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
    BEGIN
	   NEW.updated_at = now();

	   NEW.search_name = to_tsvector(NEW.name);
	   
	  RETURN NEW;
	END; $$;   
   
CREATE TRIGGER custom_label_inserted BEFORE INSERT ON labels.custom_label FOR EACH ROW EXECUTE PROCEDURE labels.custom_label_table_inserted();

CREATE TRIGGER custom_label_updated BEFORE UPDATE ON labels.custom_label FOR EACH ROW EXECUTE PROCEDURE labels.custom_label_table_updated();
      