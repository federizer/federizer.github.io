-- DROP VIEW public.message_view;

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

-- DROP TRIGGER insert_message_view_trig ON public.message_view;

CREATE TRIGGER insert_message_view_trig
    INSTEAD OF INSERT
    ON public.message_view
    FOR EACH ROW
    EXECUTE PROCEDURE public.insert_message_view_func();
	
CREATE OR REPLACE FUNCTION public.insert_message_view_func()
    RETURNS trigger
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
tmp RECORD;
BEGIN
  WITH input (id, mime_type, received_at, sent_at, subject, created_at, uufid, uumid, uupid, uurn, meta, sender) as (
     values (NEW.id, NEW.mime_type, NEW.received_at, NEW.sent_at, NEW.subject, NEW.created_at, NEW.uufid, NEW.uumid, NEW.uupid, NEW.uurn, NEW.meta, NEW.sender)
  ) 
  INSERT INTO message(id, mime_type, received_at, sent_at, subject, created_at, uufid, uumid, uupid, uurn, meta, sender_id)
  SELECT input.id, mime_type, received_at, sent_at, subject, created_at, uufid, uumid, uupid, uurn, meta, principal.id
  FROM input 
  LEFT JOIN principal ON input.sender = principal.uupn
  RETURNING * INTO tmp;
  -- NEW.sender_id = tmp.id;
  RETURN NEW;
END;

$BODY$;

ALTER FUNCTION public.insert_message_view_func()
    OWNER TO admin;