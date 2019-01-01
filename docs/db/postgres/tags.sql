CREATE SCHEMA tags;

CREATE SEQUENCE tags.tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE tags.tag (
    id bigint DEFAULT nextval('tags.tag_id_seq'::regclass) NOT NULL,
    owner character varying(255) NOT NULL,
    type smallint DEFAULT 0 NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

CREATE SEQUENCE tags.tag_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE tags.tag_value (
    id bigint DEFAULT nextval('tags.tag_value_id_seq'::regclass) NOT NULL,
    owner character varying(255) NOT NULL,
    tag_id bigint NOT NULL,
    value character varying(255) NOT NULL,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

ALTER TABLE ONLY tags.tag
    ADD CONSTRAINT tag_pkey PRIMARY KEY (id);

ALTER TABLE ONLY tags.tag_value
    ADD CONSTRAINT tag_value_pkey PRIMARY KEY (id);

ALTER TABLE ONLY tags.tag_value
    ADD CONSTRAINT value_tag_fkey FOREIGN KEY (tag_id) REFERENCES tags.tag(id);

CREATE FUNCTION tags.tag_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE FUNCTION tags.tag_value_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
   
CREATE TRIGGER tags_tag_updated BEFORE UPDATE ON tags.tag FOR EACH ROW EXECUTE PROCEDURE tags.tag_table_updated();

CREATE TRIGGER tags_tag_value_updated BEFORE UPDATE ON tags.tag_value FOR EACH ROW EXECUTE PROCEDURE tags.tag_value_table_updated();
