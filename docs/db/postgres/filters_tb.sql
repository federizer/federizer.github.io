DROP SCHEMA filters CASCADE;
CREATE SCHEMA filters;

CREATE TABLE filters.filter (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    criteria text NOT NULL,
    created_at timestamp(6) with time zone DEFAULT now(),
    updated_at timestamp(6) with time zone
);

CREATE TABLE filters.postal_label_action (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    filter_id bigint NOT NULL,
    done bool,
    archived bool,
    starred bool,
    important bool,
    chats bool,
    spam bool,
    unread bool,
    trash bool
);

CREATE TYPE filters.custom_label_actions AS ENUM ('add', 'remove');   

CREATE TABLE filters.custom_label_action (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    filter_id bigint NOT NULL,
    custom_label_id bigint NOT NULL,
    custom_label_action filters.custom_label_actions
);

CREATE TABLE filters.forward_action (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY NOT NULL,
    owner character varying(255) NOT NULL,
    filter_id bigint NOT NULL,
    recipient_email_address character varying(255) NOT NULL
);

ALTER TABLE ONLY filters.filter
    ADD CONSTRAINT filter_id_owner_unique UNIQUE (id, owner);

ALTER TABLE ONLY filters.filter
    ADD CONSTRAINT filter_name_owner_unique UNIQUE (name, owner);

ALTER TABLE ONLY filters.postal_label_action
    ADD CONSTRAINT postal_label_action_filter_unique UNIQUE (owner, filter_id, done, archived, starred, important, chats, spam, unread, trash); 
   
ALTER TABLE ONLY filters.custom_label_action
    ADD CONSTRAINT custom_label_action_filter_custom_label_unique UNIQUE (owner, filter_id, custom_label_id); 
   
ALTER TABLE ONLY filters.forward_action
    ADD CONSTRAINT forward_action_filter_unique UNIQUE (owner, filter_id); 

ALTER TABLE ONLY filters.postal_label_action
    ADD CONSTRAINT postal_label_action_filter_id_owner_fkey FOREIGN KEY (filter_id, owner) REFERENCES filters.filter(id, owner) ON DELETE CASCADE;    

ALTER TABLE ONLY filters.custom_label_action
    ADD CONSTRAINT custom_label_action_filter_id_owner_fkey FOREIGN KEY (filter_id, owner) REFERENCES filters.filter(id, owner) ON DELETE CASCADE,
    ADD CONSTRAINT custom_label_action_custom_label_id_owner_fkey FOREIGN KEY (custom_label_id, owner) REFERENCES labels.custom_label(id, owner);   
   
ALTER TABLE ONLY filters.forward_action
    ADD CONSTRAINT forward_action_filter_id_owner_fkey FOREIGN KEY (filter_id, owner) REFERENCES filters.filter(id, owner) ON DELETE CASCADE;    
   
CREATE FUNCTION filters.filter_table_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER filters_filter_updated BEFORE UPDATE ON filters.filter FOR EACH ROW EXECUTE PROCEDURE filters.filter_table_updated();
