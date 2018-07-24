--
-- PostgreSQL database dump
--

-- Dumped from database version 10.1
-- Dumped by pg_dump version 10.4

-- Started on 2018-07-17 14:23:03

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 12924)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2877 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- TOC entry 1 (class 3079 OID 21774)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA pg_catalog;


--
-- TOC entry 2878 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 210 (class 1255 OID 21785)
-- Name: delete_message_view_func(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.delete_message_view_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
account_id uuid;
BEGIN
  account_id := (SELECT id FROM "public".account WHERE uupn = OLD.sender);
  IF account_id IS NULL
  THEN
    RAISE EXCEPTION 'Account % doesn\'t exist.', OLD.sender;
  END IF;

  DELETE FROM message WHERE id = OLD.id;
  RETURN OLD;
END;
$$;


ALTER FUNCTION public.delete_message_view_func() OWNER TO admin;

--
-- TOC entry 218 (class 1255 OID 21786)
-- Name: insert_message_view_func(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.insert_message_view_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
account_id uuid;
BEGIN
  account_id := (SELECT id FROM "public".account WHERE uupn = NEW.sender);
  IF account_id IS NULL
  THEN
    -- RAISE EXCEPTION 'Account % doesn\'t exist.', NEW.sender;
	account_id = uuid_generate_v4();
	INSERT INTO account(id, uupn)
    VALUES (account_id, NEW.sender);
  END IF;
  
  INSERT INTO message(id, mime_type, sent_at, subject, created_at, uufid, uumid, uupid, uurn, meta, body, plaintext, sender_id)
  VALUES (NEW.id, NEW.mime_type, NEW.sent_at, NEW.subject, NEW.created_at, NEW.uufid, NEW.uumid, NEW.uupid, NEW.uurn, NEW.meta, NEW.body, NEW.plaintext, account_id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.insert_message_view_func() OWNER TO admin;

--
-- TOC entry 219 (class 1255 OID 21787)
-- Name: update_message_view_func(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.update_message_view_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
account_id uuid;
BEGIN
  account_id := (SELECT id FROM "public".account WHERE uupn = NEW.sender);
  IF account_id IS NULL
  THEN
    RAISE EXCEPTION 'Account % doesn\'t exist.', NEW.sender;
  END IF;
  
  UPDATE message SET
     mime_type = NEW.mime_type,
     subject = NEW.subject
  WHERE id = OLD.id; 
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_message_view_func() OWNER TO admin;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 204 (class 1259 OID 21824)
-- Name: account; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.account (
    id uuid NOT NULL,
    uupn character varying(255) NOT NULL,
    identity_id uuid
);


ALTER TABLE public.account OWNER TO admin;

--
-- TOC entry 197 (class 1259 OID 21788)
-- Name: attachment; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.attachment (
    id uuid NOT NULL,
    file_name character varying(255) NOT NULL,
    mime_type character varying(255) NOT NULL,
    uuaid uuid NOT NULL,
    uufid uuid NOT NULL,
    message_id uuid NOT NULL,
    meta jsonb,
    plaintext text
);


ALTER TABLE public.attachment OWNER TO admin;

--
-- TOC entry 198 (class 1259 OID 21794)
-- Name: envelope; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.envelope (
    id uuid NOT NULL,
    uueid uuid NOT NULL,
    message_id uuid NOT NULL,
    recipient_id uuid NOT NULL,
    received_at timestamp(6) without time zone,
    meta jsonb
);


ALTER TABLE public.envelope OWNER TO admin;

--
-- TOC entry 199 (class 1259 OID 21800)
-- Name: envelope_label; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.envelope_label (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    envelope_id uuid NOT NULL
);


ALTER TABLE public.envelope_label OWNER TO admin;

--
-- TOC entry 200 (class 1259 OID 21803)
-- Name: envelope_properties; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.envelope_properties (
    id uuid NOT NULL,
    meta jsonb,
    rejected boolean DEFAULT false NOT NULL,
    starred boolean DEFAULT false NOT NULL,
    unread boolean DEFAULT true NOT NULL,
    envelope_id uuid NOT NULL
);


ALTER TABLE public.envelope_properties OWNER TO admin;

--
-- TOC entry 201 (class 1259 OID 21812)
-- Name: identity; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.identity (
    id uuid NOT NULL
);


ALTER TABLE public.identity OWNER TO admin;

--
-- TOC entry 202 (class 1259 OID 21815)
-- Name: message; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.message (
    id uuid NOT NULL,
    mime_type character varying(255) NOT NULL,
    sent_at timestamp(6) without time zone,
    subject character varying(255),
    created_at timestamp(6) without time zone NOT NULL,
    uufid uuid NOT NULL,
    uumid uuid NOT NULL,
    uupid uuid,
    uurn uuid NOT NULL,
    sender_id uuid NOT NULL,
    meta jsonb,
    received timestamp without time zone,
    sent timestamp without time zone,
    body text,
    plaintext text
);


ALTER TABLE public.message OWNER TO admin;

--
-- TOC entry 203 (class 1259 OID 21821)
-- Name: message_properties; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.message_properties (
    id uuid NOT NULL,
    created timestamp(6) without time zone NOT NULL,
    modified timestamp(6) without time zone,
    message_id uuid NOT NULL
);


ALTER TABLE public.message_properties OWNER TO admin;

--
-- TOC entry 205 (class 1259 OID 21827)
-- Name: message_view; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.message_view AS
 SELECT message.id,
    message.mime_type,
    message.sent_at,
    message.subject,
    message.created_at,
    message.uufid,
    message.uumid,
    message.uupid,
    message.uurn,
    message.meta,
    account.uupn AS sender
   FROM (public.message
     JOIN public.account ON ((message.sender_id = account.id)));


ALTER TABLE public.message_view OWNER TO admin;

--
-- TOC entry 2712 (class 2606 OID 21832)
-- Name: attachment attachment_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT attachment_pkey PRIMARY KEY (id);


--
-- TOC entry 2718 (class 2606 OID 21834)
-- Name: envelope_label envelope_label_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_label
    ADD CONSTRAINT envelope_label_pkey PRIMARY KEY (id);


--
-- TOC entry 2716 (class 2606 OID 21836)
-- Name: envelope envelope_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope
    ADD CONSTRAINT envelope_pkey PRIMARY KEY (id);


--
-- TOC entry 2720 (class 2606 OID 21838)
-- Name: envelope_properties envelope_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_properties
    ADD CONSTRAINT envelope_properties_pkey PRIMARY KEY (id);


--
-- TOC entry 2734 (class 2606 OID 21840)
-- Name: account identity_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT identity_pkey PRIMARY KEY (id);


--
-- TOC entry 2724 (class 2606 OID 21842)
-- Name: identity identity_pkey1; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.identity
    ADD CONSTRAINT identity_pkey1 PRIMARY KEY (id);


--
-- TOC entry 2726 (class 2606 OID 21844)
-- Name: message message_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- TOC entry 2730 (class 2606 OID 21846)
-- Name: message_properties message_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message_properties
    ADD CONSTRAINT message_properties_pkey PRIMARY KEY (id);


--
-- TOC entry 2714 (class 2606 OID 21848)
-- Name: attachment uk_attachment_uufid; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT uk_attachment_uufid UNIQUE (uufid);


--
-- TOC entry 2722 (class 2606 OID 21850)
-- Name: envelope_properties uk_i2quyacqckuwwy7meak8xeqap; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_properties
    ADD CONSTRAINT uk_i2quyacqckuwwy7meak8xeqap UNIQUE (envelope_id);


--
-- TOC entry 2736 (class 2606 OID 21852)
-- Name: account uk_identity_upn; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT uk_identity_upn UNIQUE (uupn);


--
-- TOC entry 2728 (class 2606 OID 21854)
-- Name: message uk_message_uufid; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT uk_message_uufid UNIQUE (uufid);


--
-- TOC entry 2732 (class 2606 OID 21856)
-- Name: message_properties uk_o7txfb0shd3p577wyd7ikrfhv; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message_properties
    ADD CONSTRAINT uk_o7txfb0shd3p577wyd7ikrfhv UNIQUE (message_id);


--
-- TOC entry 2745 (class 2620 OID 21857)
-- Name: message_view delete_message_view_trig; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER delete_message_view_trig INSTEAD OF DELETE ON public.message_view FOR EACH ROW EXECUTE PROCEDURE public.delete_message_view_func();


--
-- TOC entry 2746 (class 2620 OID 21858)
-- Name: message_view insert_message_view_trig; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER insert_message_view_trig INSTEAD OF INSERT ON public.message_view FOR EACH ROW EXECUTE PROCEDURE public.insert_message_view_func();


--
-- TOC entry 2747 (class 2620 OID 21859)
-- Name: message_view update_message_view_trig; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER update_message_view_trig INSTEAD OF UPDATE ON public.message_view FOR EACH ROW EXECUTE PROCEDURE public.update_message_view_func();


--
-- TOC entry 2744 (class 2606 OID 21895)
-- Name: account fk_account_identity_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT fk_account_identity_id FOREIGN KEY (identity_id) REFERENCES public.identity(id);


--
-- TOC entry 2737 (class 2606 OID 21860)
-- Name: attachment fk_attachment_message_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT fk_attachment_message_id FOREIGN KEY (message_id) REFERENCES public.message(id) ON DELETE CASCADE;


--
-- TOC entry 2740 (class 2606 OID 21865)
-- Name: envelope_label fk_envelope_label_envelope_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_label
    ADD CONSTRAINT fk_envelope_label_envelope_id FOREIGN KEY (envelope_id) REFERENCES public.envelope(id);


--
-- TOC entry 2738 (class 2606 OID 21870)
-- Name: envelope fk_envelope_message_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope
    ADD CONSTRAINT fk_envelope_message_id FOREIGN KEY (message_id) REFERENCES public.message(id);


--
-- TOC entry 2741 (class 2606 OID 21875)
-- Name: envelope_properties fk_envelope_properties_envelope_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_properties
    ADD CONSTRAINT fk_envelope_properties_envelope_id FOREIGN KEY (envelope_id) REFERENCES public.envelope(id);


--
-- TOC entry 2739 (class 2606 OID 21880)
-- Name: envelope fk_envelope_recipient_account_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope
    ADD CONSTRAINT fk_envelope_recipient_account_id FOREIGN KEY (recipient_id) REFERENCES public.account(id);


--
-- TOC entry 2743 (class 2606 OID 21885)
-- Name: message_properties fk_message_properties_message_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message_properties
    ADD CONSTRAINT fk_message_properties_message_id FOREIGN KEY (message_id) REFERENCES public.message(id);


--
-- TOC entry 2742 (class 2606 OID 21890)
-- Name: message fk_message_sender_account_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT fk_message_sender_account_id FOREIGN KEY (sender_id) REFERENCES public.account(id);


-- Completed on 2018-07-17 14:23:03

--
-- PostgreSQL database dump complete
--

