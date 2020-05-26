CREATE OR REPLACE FUNCTION repository.read_file(IN _owner character varying, IN _file_id int8)
  RETURNS TABLE(id int8,
                uufid uuid,
                uufcid uuid,
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
		SELECT  f.id,
			f.uufid,
			fc.uufcid,
			f.filename,
			fc.destination,
			f.mimetype,
			f.encoding,
			fc.size
			FROM repository.file f
			LEFT JOIN LATERAL (
				SELECT 	c.uufcid,
						c.destination,
						c.size,
						c.version_major,
						c.version_minor
				FROM repository.file_content c
				LEFT JOIN email.attachment a
				ON a.file_content_id = c.id AND a.file_id = c.file_id
				WHERE c.owner = _owner AND c.file_id = f.id AND a.id IS NULL
				ORDER BY c.version_major DESC, c.version_minor DESC NULLS LAST
				LIMIT 1
				) fc ON TRUE
				WHERE f.owner = _owner AND (_file_id IS NULL OR f.id = _file_id) AND fc.uufcid IS NOT NULL;
END;			
$BODY$
LANGUAGE plpgsql VOLATILE;

/*
SELECT *  FROM repository.read_file(
	'jharper@gmail.com',					-- put the _owner parameter value instead of '_owner' (varchar) jharper@gmail.com, jdoe@leadict.com, tsawyer@leadict.com, hfinn@leadict.com
	1,										-- put the _message_id parameter value instead of '_message_id' (int8) 123
	'70d2d183-49da-4400-8318-de0275167a80' 	-- put the _uufid parameter value instead of '_uuaid' (uuid) 70d2d183-49da-4400-8318-de0275167a80
);
*/

CREATE OR REPLACE FUNCTION repository.create_file(IN _owner character varying, IN _files jsonb)
  RETURNS jsonb AS
$BODY$
DECLARE
	_rec record;
	_ret_file_id int8;
	_jsonb_array jsonb := '[]';
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	FOR _rec IN SELECT
				elm->>'destination' AS destination,
				elm->>'filename' AS filename,
				(elm->>'uufcid')::uuid AS uufcid,
				elm->>'mimetype' AS mimetype,
				elm->>'encoding' AS encoding,
				(elm->>'size')::int8 AS size
			FROM jsonb_array_elements(_files)	elm
	LOOP
		INSERT INTO repository.file (owner,
									 filename,
									 mimetype,
									 encoding
									 )
		    VALUES (_owner,
				   _rec.filename,
				   _rec.mimetype,
				   _rec.encoding
			) RETURNING id INTO _ret_file_id;
		
		INSERT INTO repository.file_content (owner,
											 uufcid,
											 file_id,
											 destination,
											 size
											 )
			VALUES (
				_owner,
			    _rec.uufcid,
				_ret_file_id,
				_rec.destination,
				_rec.size
			);
		
		_jsonb_array := _jsonb_array || jsonb_build_object('id', _ret_file_id,
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

CREATE OR REPLACE FUNCTION repository.delete_file(IN _owner character varying, IN _file_id int8)
  RETURNS int8 AS
$BODY$
DECLARE
	_id int8;
	_file_cnt int8;
BEGIN
	-- _owner is required
	IF coalesce(TRIM(_owner), '') = '' THEN
		RAISE EXCEPTION '_owner is required.';
	END IF;

	-- _file_id is required
	IF _file_id IS NULL THEN
		RAISE EXCEPTION '_file_id is required.';
	END IF;

	SELECT id FROM repository.read_file(_owner, _file_id) INTO _id;

	IF _id IS NOT NULL THEN
		WITH affected_rows AS (
			DELETE FROM repository.file f -- cascade
				WHERE f.id = _id AND owner = _owner RETURNING 1
		) SELECT COUNT(*) INTO _file_cnt
			FROM affected_rows;
	END IF;

	RETURN _file_cnt;
END;			
$BODY$
LANGUAGE plpgsql VOLATILE;

