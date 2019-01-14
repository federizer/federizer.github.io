--mail.message create-------------------------------------------------------------------------------------------------------------
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jdoe@leadict.com', 'John Doe', 'Hello', 'Hello World!');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jdoe@leadict.com', 'John Doe', 'Allo', 'Allo, Allo!');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('izboran@gmail.com', 'Igor Zboran', 'Hello again', 'Hello everybody!');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('izboran@gmail.com', 'Igor Zboran', 'Invoice1', '124€');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('izboran@gmail.com', 'Igor Zboran', 'Invoice2', '15,25€');
--mail.envelope create-------------------------------------------------------------------------------------------------------------
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(1, 'to', 'izboran@gmail.com', 'Igor Zboran');
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(1, 'cc', 'hfinn@leadict.com', 'Huckleberry Finn');
INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(1, 'cc', 'tsawyer@leadict.com', 'Tom Sawyer');

INSERT INTO mail.envelope
(message_id, "type", recipient_email_address, recipient_display_name)
VALUES(2, 'to', 'izboran@gmail.com', 'Igor Zboran');
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
--labels.system_label-------------------------------------------------------------------------------------------------------------
INSERT INTO labels.system_label
(owner, message_id, folder, starred, important)
VALUES('jdoe@leadict.com', 1, 'sent', true, true);

INSERT INTO labels.system_label
(owner, message_id, folder, important, unread)
VALUES('izboran@gmail.com', 1, 'inbox', true, true);

INSERT INTO labels.system_label
(owner, message_id, folder)
VALUES('izboran@gmail.com', 3, 'sent');

INSERT INTO labels.system_label
(owner, message_id, folder, unread)
VALUES('jdoe@leadict.com', 3, 'inbox', true);

INSERT INTO labels.system_label
(owner, message_id, folder, unread)
VALUES('tsawyer@leadict.com', 3, 'inbox', false);
--labels.custom_label-------------------------------------------------------------------------------------------------------------
INSERT INTO labels.custom_label
(owner, name)
VALUES('jdoe@leadict.com', 'Igor');
INSERT INTO labels.custom_label
(owner, name)
VALUES('jdoe@leadict.com', 'Testing');
INSERT INTO labels.custom_label
(owner, name)
VALUES('izboran@gmail.com', 'John Doe');
INSERT INTO labels.custom_label
(owner, name)
VALUES('izboran@gmail.com', 'Testing');

INSERT INTO labels.has
(owner, message_id, custom_label_id)
VALUES('jdoe@leadict.com', 3, 1);
INSERT INTO labels.has
(owner, message_id, custom_label_id)
VALUES('jdoe@leadict.com', 3, 2);
INSERT INTO labels.has
(owner, message_id, custom_label_id)
VALUES('jdoe@leadict.com', 4, 2);
INSERT INTO labels.has
(owner, message_id, custom_label_id)
VALUES('izboran@gmail.com', 1, 3);
INSERT INTO labels.has
(owner, message_id, custom_label_id)
VALUES('izboran@gmail.com', 1, 4);

--mail.attachment-------------------------------------------------------------------------------------------------------------
INSERT INTO mail.attachment
(message_id, destination, filename, name, mimetype, encoding, size)
VALUES(1, './attachments/', '70d2d183-49da-4400-8318-de0275167a80', 'Hello World.txt', 'text/plain', '7bit', 14);
INSERT INTO mail.attachment
(message_id, destination, filename, name, mimetype, encoding, size)
VALUES(3, './attachments/', '7e4763e8-098b-4fdd-9f1d-565366fd1fc3', 'Hello World.txt', 'text/plain', '7bit', 14);
INSERT INTO mail.attachment
(message_id, destination, filename, name, mimetype, encoding, size)
VALUES(3, './attachments/', '114c0607-4bb4-4aca-ae8c-49ac558ac317', 'Java 8 Pocket Guide.pdf', 'application/pdf', '7bit', 8384695);
INSERT INTO mail.attachment
(message_id, destination, filename, name, mimetype, encoding, size)
VALUES(4, './attachments/', '74aa8f05-f2a2-4da4-981d-e9728f7a4fcc', 'Hello World.txt', 'text/plain', '7bit', 14);
--mail.tag-------------------------------------------------------------------------------------------------------------
INSERT INTO mail.tag
(message_id, name, value)
VALUES(1, 'Meeting', '2019-01-10 16:00:00');
INSERT INTO mail.tag
(message_id, name, value)
VALUES(3, 'Invoice', '82,50€');
INSERT INTO mail.tag
(message_id, name, value)
VALUES(3, 'Due date', '2019-01-31 23:59:59');
INSERT INTO mail.tag
(message_id, name, value)
VALUES(4, 'Meeting', '2019-01-17 14:00:00');
INSERT INTO mail.tag
(message_id, name)
VALUES(4, 'Test tag');
