DROP SCHEMA contacts CASCADE;
CREATE SCHEMA contacts;

CREATE TABLE contacts.person (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    given_name character varying(255),
    surname character varying(255),
    email_address character varying(255) NOT NULL,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

CREATE TABLE contacts.belongs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    person_id bigint NOT NULL,
    group_id bigint NOT NULL
);

CREATE TABLE contacts.group (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

ALTER TABLE ONLY contacts.person
    ADD CONSTRAINT person_email_address_unique UNIQUE (owner, email_address);   
   
ALTER TABLE ONLY contacts.belongs
    ADD CONSTRAINT belongs_person_group_unique UNIQUE (owner, person_id, group_id);   
   
ALTER TABLE ONLY contacts.group
    ADD CONSTRAINT group_name_unique UNIQUE (owner, name);   

ALTER TABLE ONLY contacts.belongs
    ADD CONSTRAINT belongs_person_fkey FOREIGN KEY (person_id) REFERENCES contacts.person(id),
    ADD CONSTRAINT belongs_group_fkey FOREIGN KEY (group_id) REFERENCES contacts.group(id);
   
CREATE FUNCTION contacts.person_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE FUNCTION contacts.group_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER contacts_person_updated BEFORE UPDATE ON contacts.person FOR EACH ROW EXECUTE PROCEDURE contacts.person_table_updated();

CREATE TRIGGER contacts_group_updated BEFORE UPDATE ON contacts.group FOR EACH ROW EXECUTE PROCEDURE contacts.group_table_updated();
