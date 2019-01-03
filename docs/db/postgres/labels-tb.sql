--
CREATE SCHEMA labels;

CREATE SEQUENCE labels.system_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
   
CREATE TYPE labels.exclusive_values AS ENUM ('inbox', 'snoozed', 'sent', 'drafts');   

CREATE TABLE labels.system_label (
    id bigint DEFAULT nextval('labels.system_label_id_seq'::regclass) NOT NULL,
    owner character varying(255) NOT NULL,
    message_id bigint NOT NULL,
    user_label_id bigint,
    state labels.exclusive_values NOT NULL DEFAULT 'inbox',
    done bool NOT NULL DEFAULT false,
    archived bool NOT NULL DEFAULT false,
    starred bool NOT NULL DEFAULT false,
    important bool NOT NULL DEFAULT false,
    chats bool NOT NULL DEFAULT false,
    spam bool NOT NULL DEFAULT false,
    trash bool NOT NULL DEFAULT false,
    unread bool NOT NULL DEFAULT true
);

CREATE SEQUENCE labels.user_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE labels.user_label (
    id bigint DEFAULT nextval('labels.user_label_id_seq'::regclass) NOT NULL,
    owner character varying(255) NOT NULL,
    user_label_id bigint,
    filter_id bigint,
    name character varying(255) NOT NULL,
    search_name tsvector,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

ALTER TABLE ONLY labels.system_label
    ADD CONSTRAINT system_label_pkey PRIMARY KEY (id);

ALTER TABLE ONLY labels.user_label
    ADD CONSTRAINT user_label_pkey PRIMARY KEY (id);

ALTER TABLE ONLY labels.system_label
    ADD CONSTRAINT system_label_message_unique UNIQUE (owner, message_id, user_label_id);

ALTER TABLE ONLY labels.user_label
    ADD CONSTRAINT user_label_name_unique UNIQUE (owner, name);

ALTER TABLE ONLY labels.system_label
    ADD CONSTRAINT system_label_message_fkey FOREIGN KEY (message_id) REFERENCES mail.message(id),
    ADD CONSTRAINT system_label_user_label_fkey FOREIGN KEY (user_label_id) REFERENCES labels.user_label(id);

ALTER TABLE ONLY labels.user_label
    ADD CONSTRAINT system_label_filter_fkey FOREIGN KEY (filter_id) REFERENCES filters.filter(id);

CREATE INDEX idx_search_user_label_name ON labels.user_label USING gin (search_name);

CREATE FUNCTION labels.user_label_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	BEGIN				
		NEW.search_name = to_tsvector(NEW.name);
	
		RETURN NEW;	
	END; $$;


CREATE FUNCTION labels.user_label_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
    BEGIN
	   NEW.updated_at = now();

	   NEW.search_name = to_tsvector(NEW.name);
	   
	  RETURN NEW;
	END; $$;   
   
CREATE TRIGGER user_label_inserted BEFORE INSERT ON labels.user_label FOR EACH ROW EXECUTE PROCEDURE labels.user_label_table_inserted();

CREATE TRIGGER user_label_updated BEFORE UPDATE ON labels.user_label FOR EACH ROW EXECUTE PROCEDURE labels.user_label_table_updated();
      