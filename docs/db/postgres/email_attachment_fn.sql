CREATE OR REPLACE FUNCTION email.read_attachment(IN _owner character varying, IN _attachment_id int8)
  RETURNS TABLE(id int8,
                uuaid uuid,
                filename character varying,
                destination character varying,
                mimetype character varying,
                encoding character varying,
                size int8) AS
$BODY$
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	RETURN QUERY
		SELECT  a.id,
				ac.uuacid,
				a.filename,
				ac.destination,
				a.mimetype,
				a.encoding,
				ac.size
				FROM email.attachment a
				RIGHT JOIN LATERAL (
					SELECT 	c.uuacid,
							c.destination,
							c.size,
							c.version_major,
							c.version_minor
					FROM email.attachment_content c
					RIGHT JOIN email.has h
					ON h.attachment_content_id = c.id AND h.attachment_id = c.attachment_id
					WHERE c.attachment_id = _attachment_id AND h.message_id IN (
						SELECT u.id AS id
						FROM (
							SELECT
								m.id AS id							
							FROM email.message m
							WHERE (m.id = h.message_id) AND (m.sender_email_address = _owner) AND NOT m.deleted_at_sender
							UNION
							SELECT
								e.message_id AS id				
							FROM email.envelope e			
							WHERE (e.message_id = h.message_id) AND (e.recipient_email_address = _owner) AND NOT e.deleted_at_recipient AND e.received_at IS NOT NULL
							) u
					)
					ORDER BY c.version_major DESC, c.version_minor DESC NULLS LAST
					LIMIT 1
					) ac ON TRUE
				WHERE a.id = _attachment_id;
END;			
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT *  FROM email.read_attachment(
	'izboran@gmail.com',					-- put the _owner parameter value instead of '_owner' (varchar) izboran@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	1,										-- put the _message_id parameter value instead of '_message_id' (int8) 123
	'70d2d183-49da-4400-8318-de0275167a80' 	-- put the _uuaid parameter value instead of '_uuaid' (uuid) 70d2d183-49da-4400-8318-de0275167a80
);
*/

CREATE OR REPLACE FUNCTION email.create_attachment(IN _owner character varying, IN _attachments jsonb)
  RETURNS jsonb AS
$BODY$
DECLARE
	_rec record;
	_ret_attachment_id int8;
	_jsonb_array jsonb := '[]';
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	FOR _rec IN SELECT
				elm->>'destination' AS destination,
				elm->>'filename' AS filename,
				(elm->>'uuacid')::uuid AS uuacid,
				elm->>'mimetype' AS mimetype,
				elm->>'encoding' AS encoding,
				(elm->>'size')::int8 AS size
			FROM jsonb_array_elements(_attachments)	elm
	LOOP
		INSERT INTO email.attachment (owner,
									 filename,
									 mimetype,
									 encoding
									 )
		    VALUES (_owner,
				   _rec.filename,
				   _rec.mimetype,
				   _rec.encoding
			) RETURNING id INTO _ret_attachment_id;
		
		INSERT INTO email.attachment_content (owner,
											 uuacid,
											 attachment_id,
											 destination,
											 size
											 )
			VALUES (
				_owner,
			    _rec.uuacid,
				_ret_attachment_id,
				_rec.destination,
				_rec.size
			);
		
		_jsonb_array := _jsonb_array || jsonb_build_object('id', _ret_attachment_id,
                                		    'filename', _rec.filename,
                                		    'destination', _rec.destination,
                                		    'mimetype', _rec.mimetype,
                                		    'encoding', _rec.encoding,
                                		    'size', _rec.size);
	END LOOP;
		
	IF jsonb_array_length(_jsonb_array) > 0 THEN
		RETURN _jsonb_array;
	ELSE
		RETURN NULL;
	END IF;
END;	   
$BODY$
LANGUAGE plpgsql VOLATILE;

