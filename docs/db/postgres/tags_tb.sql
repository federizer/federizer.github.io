DROP SCHEMA tags CASCADE;
CREATE SCHEMA tags;

--'STRING': 0, 'NUMBER': 1, 'BOOLEAN': 2, 'DATE': 3, 'TIME': 4, 'DATETIME': 5

CREATE TABLE tags.tag (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    type smallint DEFAULT 0 NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

CREATE TABLE tags.tag_value (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    tag_id bigint NOT NULL,
    value character varying(255) NOT NULL,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

-- comment out if tags are private
/*
ALTER TABLE ONLY tags.tag
    ADD CONSTRAINT tag_id_owner_unique UNIQUE (id, owner);

ALTER TABLE ONLY tags.tag_value
    ADD CONSTRAINT value_tag_id_owner_tag_fkey FOREIGN KEY (tag_id, owner) REFERENCES tags.tag(id, owner);*/

-- comment if tags are private
ALTER TABLE ONLY tags.tag_value
    ADD CONSTRAINT value_tag_id_tag_fkey FOREIGN KEY (tag_id) REFERENCES tags.tag(id);

CREATE FUNCTION tags.tag_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE FUNCTION tags.tag_value_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
   
CREATE TRIGGER tags_tag_updated BEFORE UPDATE ON tags.tag FOR EACH ROW EXECUTE PROCEDURE tags.tag_table_updated();

CREATE TRIGGER tags_tag_value_updated BEFORE UPDATE ON tags.tag_value FOR EACH ROW EXECUTE PROCEDURE tags.tag_value_table_updated();
