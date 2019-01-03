INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jdoe@leadict.com', 'John Doe', 'Hello', 'Hello World!');
INSERT INTO mail.message
(sender_email_address, sender_display_name, subject, body)
VALUES('jdoe@leadict.com', 'John Doe', 'Hello again', 'Hello everybody!');

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
