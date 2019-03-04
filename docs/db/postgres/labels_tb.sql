DROP SCHEMA labels CASCADE;
CREATE SCHEMA labels;

CREATE TABLE labels.has (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    mailbox_id bigint NOT NULL,
    custom_label_id bigint NOT NULL
);

CREATE TABLE labels.custom_label (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    custom_label_id bigint,
    name character varying(255) NOT NULL,
    search_name tsvector,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

ALTER TABLE ONLY labels.has
    ADD CONSTRAINT has_message_custom_label_unique UNIQUE (owner, mailbox_id, custom_label_id); 
   
ALTER TABLE ONLY labels.custom_label
    ADD CONSTRAINT custom_label_id_owner_unique UNIQUE (id, owner);

ALTER TABLE ONLY labels.custom_label
    ADD CONSTRAINT custom_label_name_owner_unique UNIQUE (name, owner);

ALTER TABLE ONLY labels.custom_label
    ADD CONSTRAINT custom_label_custom_label_fkey FOREIGN KEY (custom_label_id, owner) REFERENCES labels.custom_label(id, owner);

ALTER TABLE ONLY labels.has
    ADD CONSTRAINT has_mailbox_id_owner_fkey FOREIGN KEY (mailbox_id, owner) REFERENCES postal.mailbox(id, owner) ON DELETE CASCADE,
    ADD CONSTRAINT has_custom_label_id_owner_fkey FOREIGN KEY (custom_label_id, owner) REFERENCES labels.custom_label(id, owner);
   
CREATE INDEX idx_search_custom_label_name ON labels.custom_label USING gin (search_name);

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
      