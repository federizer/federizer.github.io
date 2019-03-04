/*DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
   
CREATE EXTENSION "pgcrypto" WITH SCHEMA public;*/

DROP SCHEMA repository CASCADE;
CREATE SCHEMA repository;

CREATE TABLE repository.file (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    uufid uuid NOT NULL DEFAULT public.gen_random_uuid(), 	-- universally unique file identifier
    filename character varying(255) NOT NULL,
    mimetype character varying(255) NOT NULL,
    encoding character varying(255) NOT NULL,
    search_filename tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE TABLE repository.file_content (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    uufcid uuid NOT NULL, 									-- universally unique file content identifier
    file_id bigint NOT NULL,
    version_major int4 NOT NULL DEFAULT 1,
    version_minor int4 NOT NULL DEFAULT 1,
    destination character varying(4096) NOT NULL,
    size bigint NOT NULL,
    content text,
    search_content tsvector,
    created_at timestamp(6) with time zone DEFAULT now()
);

CREATE FUNCTION repository.file_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	BEGIN				
		NEW.search_filename = to_tsvector(NEW.filename);
	
		RETURN NEW;	
	END; $$;

CREATE FUNCTION repository.file_content_table_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	DECLARE
	search_content text;
	BEGIN				
		NEW.search_content = to_tsvector(search_content);
	
		RETURN NEW;	
	END; $$;
   

CREATE OR REPLACE FUNCTION repository.prevent_update() RETURNS trigger AS
$BODY$
    BEGIN
        RAISE EXCEPTION 'update not allowed';
        RETURN NULL;
    END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
ALTER TABLE ONLY repository.file
    ADD CONSTRAINT file_id_owner_unique UNIQUE (id, owner);

ALTER TABLE ONLY repository.file_content
    ADD CONSTRAINT file_content_id_file_id_unique UNIQUE (id, file_id),
    ADD CONSTRAINT file_content_versions_unique UNIQUE (file_id, version_major, version_minor);

ALTER TABLE ONLY repository.file_content
    ADD CONSTRAINT file_content_file_id_file_fkey FOREIGN KEY (file_id) REFERENCES repository.file(id) ON DELETE CASCADE;
   
CREATE INDEX idx_search_file_filename ON repository.file USING gin (search_filename);
CREATE INDEX idx_search_file_content ON repository.file_content USING gin (search_content);

CREATE TRIGGER email_file_inserted BEFORE INSERT ON repository.file FOR EACH ROW EXECUTE PROCEDURE repository.file_table_inserted();
CREATE TRIGGER email_file_content_inserted BEFORE INSERT ON repository.file_content FOR EACH ROW EXECUTE PROCEDURE repository.file_content_table_inserted();

CREATE TRIGGER email_prevent_update BEFORE UPDATE ON repository.file FOR EACH ROW EXECUTE PROCEDURE repository.prevent_update();
CREATE TRIGGER email_prevent_update BEFORE UPDATE ON repository.file_content FOR EACH ROW EXECUTE PROCEDURE repository.prevent_update();
