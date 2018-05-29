DROP VIEW public.message_view;

CREATE OR REPLACE VIEW public.message_view AS
 SELECT message.id,
    message.mime_type,
    message.received_at,
    message.sent_at,
    message.subject,
    message.created_at,
    message.uufid,
    message.uumid,
    message.uupid,
    message.uurn,
    message.meta,
    principal.uupn AS sender
   FROM message
     JOIN principal ON message.sender_id = principal.id;

ALTER TABLE public.message_view
    OWNER TO admin;

CREATE OR REPLACE FUNCTION public.insert_message_view_func()
    RETURNS trigger
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
principal_id uuid;
BEGIN
  principal_id := (SELECT id FROM "public".principal WHERE uupn = NEW.sender);
  IF principal_id IS NULL
  THEN
    RAISE EXCEPTION 'Principal % is not registered.', NEW.sender;
  END IF;
  
  INSERT INTO message(id, mime_type, received_at, sent_at, subject, created_at, uufid, uumid, uupid, uurn, meta, sender_id)
  VALUES (NEW.id, NEW.mime_type, NEW.received_at, NEW.sent_at, NEW.subject, NEW.created_at, NEW.uufid, NEW.uumid, NEW.uupid, NEW.uurn, NEW.meta, principal_id);
  RETURN NEW;
END;
$BODY$;

-- DROP TRIGGER insert_message_view_trig ON public.message_view;

CREATE TRIGGER insert_message_view_trig
    INSTEAD OF INSERT
    ON public.message_view
    FOR EACH ROW
    EXECUTE PROCEDURE public.insert_message_view_func();
	
ALTER FUNCTION public.insert_message_view_func()
    OWNER TO admin;

CREATE OR REPLACE FUNCTION public.delete_message_view_func()
    RETURNS trigger
    LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
  DELETE FROM message WHERE id = OLD.id;
  RETURN NEW;
END;
$BODY$;

-- DROP TRIGGER delete_message_view_trig ON public.message_view;

CREATE TRIGGER delete_message_view_trig
    INSTEAD OF DELETE
    ON public.message_view
    FOR EACH ROW
    EXECUTE PROCEDURE public.delete_message_view_func();
	
ALTER FUNCTION public.delete_message_view_func()
    OWNER TO admin;

CREATE OR REPLACE FUNCTION public.update_message_view_func()
    RETURNS trigger
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
principal_id uuid;
BEGIN
  principal_id := (SELECT id FROM "public".principal WHERE uupn = NEW.sender);
  IF principal_id IS NULL
  THEN
    RAISE EXCEPTION 'Principal % is not registered.', NEW.sender;
  END IF;
  
  UPDATE message SET
     mime_type = NEW.mime_type,
     subject = NEW.subject
  WHERE id = OLD.id; 
  RETURN NEW;
END;
$BODY$;

-- DROP TRIGGER update_message_view_trig ON public.message_view;

CREATE TRIGGER update_message_view_trig
    INSTEAD OF UPDATE
    ON public.message_view
    FOR EACH ROW
    EXECUTE PROCEDURE public.update_message_view_func();
	
ALTER FUNCTION public.update_message_view_func()
    OWNER TO admin;

