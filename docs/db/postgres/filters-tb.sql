DROP SCHEMA filters CASCADE;
CREATE SCHEMA filters;

CREATE TABLE filters.filter (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    name character varying(255),
    criteria text NOT NULL,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

ALTER TABLE ONLY filters.filter
    ADD CONSTRAINT name_unique UNIQUE (owner, name);   
   
CREATE FUNCTION filters.filter_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER filters_filter_updated BEFORE UPDATE ON filters.filter FOR EACH ROW EXECUTE PROCEDURE filters.filter_table_updated();
