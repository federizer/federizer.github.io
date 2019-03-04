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

ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_id_owner_unique UNIQUE (id, owner);

ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_message_id_unique UNIQUE (message_id, owner);

ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_envelope_id_unique UNIQUE (envelope_id, owner);
   
ALTER TABLE ONLY postal.mailbox
    ADD CONSTRAINT mailbox_message_id_message_fkey FOREIGN KEY (message_id, owner) REFERENCES email.message(id, sender_email_address) ON DELETE CASCADE,
    ADD CONSTRAINT mailbox_envelope_id_envelope_fkey FOREIGN KEY (envelope_id, owner) REFERENCES email.envelope(id, recipient_email_address) ON DELETE CASCADE,
	ADD CONSTRAINT message_id_xor_envelope_id CHECK ((message_id IS NULL) != (envelope_id IS NULL)),
	ADD CONSTRAINT mailbox_valid_folders CHECK ((message_id IS NOT NULL AND folder IN ('sent'::postal.mailbox_folders, 'drafts'::postal.mailbox_folders)) OR
													(envelope_id IS NOT NULL AND folder IN ('inbox'::postal.mailbox_folders, 'snoozed'::postal.mailbox_folders)));
													