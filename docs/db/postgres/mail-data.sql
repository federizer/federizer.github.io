--mail.message-------------------------------------------------------------------------------------------------------------
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body, sent_at)
VALUES('jdoe@leadict.com', 'John Doe', 'Hello', 'Hello World!', '2019-01-06 10:21:04');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body, sent_at)
VALUES('jdoe@leadict.com', 'John Doe', 'Allo', 'Allo, Allo!', '2019-01-07 12:41:53');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body, sent_at)
VALUES('izboran@gmail.com', 'Igor Zboran', 'Hello again', 'Hello everybody!', '2019-01-07 17:08:29');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('izboran@gmail.com', 'Igor Zboran', 'Invoice1', '124€');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('izboran@gmail.com', 'Igor Zboran', 'Invoice2', '15,25€');
--mail.envelope-------------------------------------------------------------------------------------------------------------
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
--labels.system_label-------------------------------------------------------------------------------------------------------------
INSERT INTO labels.system_label
(owner, message_id, folder, unread)
VALUES('izboran@gmail.com', 3, 'sent', true);

INSERT INTO labels.system_label
(owner, message_id, folder, unread)
VALUES('jdoe@leadict.com', 3, 'inbox', true);

INSERT INTO labels.system_label
(owner, message_id, folder, unread)
VALUES('tsawyer@leadict.com', 3, 'inbox', false);

