--mail.message create-------------------------------------------------------------------------------------------------------------
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jdoe@leadict.com', 'John Doe', 'Hello', 'Hello World!');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jdoe@leadict.com', 'John Doe', 'Allo', 'Allo, Allo!');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jharper@gmail.com', 'Joe Harper', 'Hello again', 'Hello everybody!');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jharper@gmail.com', 'Joe Harper', 'Invoice1', '124�');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jharper@gmail.com', 'Joe Harper', 'Invoice2', '15,25�');
--mail.envelope create-------------------------------------------------------------------------------------------------------------
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(1, 'to', 'jharper@gmail.com', 'Joe Harper');
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(1, 'cc', 'hfinn@leadict.com', 'Huckleberry Finn');
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(1, 'cc', 'tsawyer@leadict.com', 'Tom Sawyer');

INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(2, 'to', 'jharper@gmail.com', 'Joe Harper');
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(2, 'cc', 'hfinn@leadict.com', 'Huckleberry Finn');
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(2, 'bcc', 'tsawyer@leadict.com', 'Tom Sawyer');

INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(3, 'to', 'jdoe@leadict.com', 'John Doe');
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(3, 'cc', 'tsawyer@leadict.com', 'Tom Sawyer');

INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(4, 'to', 'jdoe@leadict.com', 'John Doe');
--mail.message & mail.envelope update------------------------------------------------------------------------------------------------------
UPDATE mail.message SET
sent_at = '2019-02-06 10:21:04'
WHERE id = 1;
UPDATE mail.envelope SET
received_at = '2019-02-06 10:21:04'
WHERE message_id = 1;
UPDATE mail.message SET
sent_at = '2019-02-07 12:41:53'
WHERE id = 2;
UPDATE mail.envelope SET
received_at = '2019-02-07 12:41:53'
WHERE message_id = 2;
UPDATE mail.message SET
sent_at = '2019-02-07 17:08:29'
WHERE id = 3;
UPDATE mail.envelope SET
received_at = '2019-02-08 07:04:09'
WHERE message_id = 3 AND id = 8;
UPDATE mail.envelope SET
received_at = '2019-02-08 10:01:45'
WHERE message_id = 3 AND id = 7;
UPDATE mail.envelope SET
snoozed_at = '2019-02-09 06:30:00'
WHERE message_id = 2 AND id = 4;
--postal.mailbox-------------------------------------------------------------------------------------------------------------
INSERT INTO postal.mailbox
(owner, message_id, envelope_id, folder, starred, important)
VALUES('jdoe@leadict.com', 1, NULL, 'sent', true, true);

INSERT INTO postal.mailbox
(owner, message_id, envelope_id, folder, important, unread)
VALUES('jharper@gmail.com', NULL, 1, 'inbox', true, true);

INSERT INTO postal.mailbox
(owner, message_id, envelope_id, folder)
VALUES('jharper@gmail.com', 3, NULL, 'sent');

INSERT INTO postal.mailbox
(owner, message_id, envelope_id, folder, unread)
VALUES('jdoe@leadict.com', NULL, 7, 'inbox', true);

INSERT INTO postal.mailbox
(owner, message_id, envelope_id, folder, unread)
VALUES('tsawyer@leadict.com', NULL, 8, 'inbox', false);

INSERT INTO postal.mailbox
(owner, message_id, envelope_id, folder)
VALUES('jharper@gmail.com', 4, NULL, 'drafts');
--labels.custom_label-------------------------------------------------------------------------------------------------------------
INSERT INTO labels.custom_label
(owner, name)
VALUES('jdoe@leadict.com', 'Joe');
INSERT INTO labels.custom_label
(owner, name)
VALUES('jdoe@leadict.com', 'Testing');
INSERT INTO labels.custom_label
(owner, name)
VALUES('jharper@gmail.com', 'John Doe');
INSERT INTO labels.custom_label
(owner, name)
VALUES('jharper@gmail.com', 'Testing');

INSERT INTO labels.has
(owner, mailbox_id, custom_label_id)
VALUES('jdoe@leadict.com', 4, 1);
INSERT INTO labels.has
(owner, mailbox_id, custom_label_id)
VALUES('jdoe@leadict.com', 4, 2);
INSERT INTO labels.has
(owner, mailbox_id, custom_label_id)
VALUES('jharper@gmail.com', 6, 4);
INSERT INTO labels.has
(owner, mailbox_id, custom_label_id)
VALUES('jharper@gmail.com', 2, 3);
INSERT INTO labels.has
(owner, mailbox_id, custom_label_id)
VALUES('jharper@gmail.com', 2, 4);
--mail.attachment-------------------------------------------------------------------------------------------------------------
INSERT INTO mail.attachment
(message_id, uuaid, filename, destination, mimetype, encoding, size)
VALUES(1, '70d2d183-49da-4400-8318-de0275167a80', 'Hello World.txt', './attachments/', 'text/plain', '7bit', 14);
INSERT INTO mail.attachment
(message_id, uuaid, filename, destination, mimetype, encoding, size)
VALUES(3, '7e4763e8-098b-4fdd-9f1d-565366fd1fc3', 'Hello World.txt', './attachments/', 'text/plain', '7bit', 14);
INSERT INTO mail.attachment
(message_id, uuaid, filename, destination, mimetype, encoding, size)
VALUES(3, '114c0607-4bb4-4aca-ae8c-49ac558ac317', 'Java 8 Pocket Guide.pdf', './attachments/', 'application/pdf', '7bit', 8384695);
INSERT INTO mail.attachment
(message_id, uuaid, filename, destination, mimetype, encoding, size)
VALUES(4, '74aa8f05-f2a2-4da4-981d-e9728f7a4fcc', 'Hello World.txt', './attachments/', 'text/plain', '7bit', 14);
--mail.tag-------------------------------------------------------------------------------------------------------------
--'STRING': 0, 'NUMBER': 1, 'BOOLEAN': 2, 'DATE': 3, 'TIME': 4, 'DATETIME': 5
INSERT INTO mail.tag
(message_id, type, name, value)
VALUES(1, 5, 'Meeting', '2019-01-10 16:00:00');
INSERT INTO mail.tag
(message_id, type, name, value)
VALUES(3, 1, 'Invoice', '82,50'); -- $,� currency ?
INSERT INTO mail.tag
(message_id, type, name, value)
VALUES(3, 5, 'Due date', '2019-01-31 23:59:59');
INSERT INTO mail.tag
(message_id, type, name, value)
VALUES(4, 5, 'Meeting', '2019-01-17 14:00:00');
INSERT INTO mail.tag
(message_id, type, name)
VALUES(4, 0, 'Test tag');
