--
-- PostgreSQL database dump
--

-- Dumped from database version 10.1
-- Dumped by pg_dump version 10.4

-- Started on 2018-07-11 12:45:19

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
-- TOC entry 1 (class 3079 OID 12924)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2876 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- TOC entry 217 (class 1255 OID 21201)
-- Name: delete_message_view_func(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.delete_message_view_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
principal_id uuid;
BEGIN
  principal_id := (SELECT id FROM "public".principal WHERE uupn = OLD.sender);
  IF principal_id IS NULL
  THEN
    RAISE EXCEPTION 'Principal % is not registered.', OLD.sender;
  END IF;

  DELETE FROM message WHERE id = OLD.id;
  RETURN OLD;
END;
$$;


ALTER FUNCTION public.delete_message_view_func() OWNER TO admin;

--
-- TOC entry 210 (class 1255 OID 21042)
-- Name: insert_message_view_func(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.insert_message_view_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
principal_id uuid;
BEGIN
  principal_id := (SELECT id FROM "public".principal WHERE uupn = NEW.sender);
  IF principal_id IS NULL
  THEN
    RAISE EXCEPTION 'Principal % is not registered.', NEW.sender;
  END IF;
  
  INSERT INTO message(id, mime_type, received_at, sent_at, subject, created_at, uufid, uumid, uupid, uurn, meta, body, plaintext, sender_id)
  VALUES (NEW.id, NEW.mime_type, NEW.received_at, NEW.sent_at, NEW.subject, NEW.created_at, NEW.uufid, NEW.uumid, NEW.uupid, NEW.uurn, NEW.meta, NEW.body, NEW.plaintext, principal_id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.insert_message_view_func() OWNER TO admin;

--
-- TOC entry 211 (class 1255 OID 21228)
-- Name: update_message_view_func(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.update_message_view_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_message_view_func() OWNER TO admin;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 196 (class 1259 OID 20929)
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
-- TOC entry 197 (class 1259 OID 20939)
-- Name: envelope; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.envelope (
    id uuid NOT NULL,
    uueid uuid NOT NULL,
    message_id uuid NOT NULL,
    recipient_id uuid NOT NULL,
    meta jsonb
);


ALTER TABLE public.envelope OWNER TO admin;

--
-- TOC entry 198 (class 1259 OID 20947)
-- Name: envelope_label; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.envelope_label (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    envelope_id uuid NOT NULL
);


ALTER TABLE public.envelope_label OWNER TO admin;

--
-- TOC entry 199 (class 1259 OID 20952)
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
-- TOC entry 203 (class 1259 OID 20989)
-- Name: identity; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.identity (
    id uuid NOT NULL
);


ALTER TABLE public.identity OWNER TO admin;

--
-- TOC entry 201 (class 1259 OID 20972)
-- Name: message; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.message (
    id uuid NOT NULL,
    mime_type character varying(255) NOT NULL,
    received_at timestamp(6) without time zone,
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
-- TOC entry 202 (class 1259 OID 20982)
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
-- TOC entry 200 (class 1259 OID 20965)
-- Name: principal; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.principal (
    id uuid NOT NULL,
    uupn character varying(255) NOT NULL,
    identity_id uuid
);


ALTER TABLE public.principal OWNER TO admin;

--
-- TOC entry 204 (class 1259 OID 21256)
-- Name: message_view; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.message_view AS
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
   FROM (public.message
     JOIN public.principal ON ((message.sender_id = principal.id)));


ALTER TABLE public.message_view OWNER TO admin;

--
-- TOC entry 2711 (class 2606 OID 20936)
-- Name: attachment attachment_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT attachment_pkey PRIMARY KEY (id);


--
-- TOC entry 2717 (class 2606 OID 20951)
-- Name: envelope_label envelope_label_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_label
    ADD CONSTRAINT envelope_label_pkey PRIMARY KEY (id);


--
-- TOC entry 2715 (class 2606 OID 20946)
-- Name: envelope envelope_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope
    ADD CONSTRAINT envelope_pkey PRIMARY KEY (id);


--
-- TOC entry 2719 (class 2606 OID 20962)
-- Name: envelope_properties envelope_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_properties
    ADD CONSTRAINT envelope_properties_pkey PRIMARY KEY (id);


--
-- TOC entry 2723 (class 2606 OID 20969)
-- Name: principal identity_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.principal
    ADD CONSTRAINT identity_pkey PRIMARY KEY (id);


--
-- TOC entry 2735 (class 2606 OID 20993)
-- Name: identity identity_pkey1; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.identity
    ADD CONSTRAINT identity_pkey1 PRIMARY KEY (id);


--
-- TOC entry 2727 (class 2606 OID 20979)
-- Name: message message_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- TOC entry 2731 (class 2606 OID 20986)
-- Name: message_properties message_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message_properties
    ADD CONSTRAINT message_properties_pkey PRIMARY KEY (id);


--
-- TOC entry 2713 (class 2606 OID 20938)
-- Name: attachment uk_attachment_uufid; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT uk_attachment_uufid UNIQUE (uufid);


--
-- TOC entry 2721 (class 2606 OID 20964)
-- Name: envelope_properties uk_i2quyacqckuwwy7meak8xeqap; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_properties
    ADD CONSTRAINT uk_i2quyacqckuwwy7meak8xeqap UNIQUE (envelope_id);


--
-- TOC entry 2725 (class 2606 OID 20971)
-- Name: principal uk_identity_upn; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.principal
    ADD CONSTRAINT uk_identity_upn UNIQUE (uupn);


--
-- TOC entry 2729 (class 2606 OID 20981)
-- Name: message uk_message_uufid; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT uk_message_uufid UNIQUE (uufid);


--
-- TOC entry 2733 (class 2606 OID 20988)
-- Name: message_properties uk_o7txfb0shd3p577wyd7ikrfhv; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message_properties
    ADD CONSTRAINT uk_o7txfb0shd3p577wyd7ikrfhv UNIQUE (message_id);


--
-- TOC entry 2745 (class 2620 OID 21261)
-- Name: message_view delete_message_view_trig; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER delete_message_view_trig INSTEAD OF DELETE ON public.message_view FOR EACH ROW EXECUTE PROCEDURE public.delete_message_view_func();


--
-- TOC entry 2744 (class 2620 OID 21260)
-- Name: message_view insert_message_view_trig; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER insert_message_view_trig INSTEAD OF INSERT ON public.message_view FOR EACH ROW EXECUTE PROCEDURE public.insert_message_view_func();


--
-- TOC entry 2746 (class 2620 OID 21262)
-- Name: message_view update_message_view_trig; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER update_message_view_trig INSTEAD OF UPDATE ON public.message_view FOR EACH ROW EXECUTE PROCEDURE public.update_message_view_func();


--
-- TOC entry 2736 (class 2606 OID 20994)
-- Name: attachment fk_attachment_message_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT fk_attachment_message_id FOREIGN KEY (message_id) REFERENCES public.message(id) ON DELETE CASCADE;


--
-- TOC entry 2739 (class 2606 OID 21009)
-- Name: envelope_label fk_envelope_label_envelope_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_label
    ADD CONSTRAINT fk_envelope_label_envelope_id FOREIGN KEY (envelope_id) REFERENCES public.envelope(id);


--
-- TOC entry 2738 (class 2606 OID 21004)
-- Name: envelope fk_envelope_message_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope
    ADD CONSTRAINT fk_envelope_message_id FOREIGN KEY (message_id) REFERENCES public.message(id);


--
-- TOC entry 2740 (class 2606 OID 21014)
-- Name: envelope_properties fk_envelope_properties_envelope_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope_properties
    ADD CONSTRAINT fk_envelope_properties_envelope_id FOREIGN KEY (envelope_id) REFERENCES public.envelope(id);


--
-- TOC entry 2737 (class 2606 OID 20999)
-- Name: envelope fk_envelope_recipient_principal_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.envelope
    ADD CONSTRAINT fk_envelope_recipient_principal_id FOREIGN KEY (recipient_id) REFERENCES public.principal(id);


--
-- TOC entry 2743 (class 2606 OID 21029)
-- Name: message_properties fk_message_properties_message_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message_properties
    ADD CONSTRAINT fk_message_properties_message_id FOREIGN KEY (message_id) REFERENCES public.message(id);


--
-- TOC entry 2742 (class 2606 OID 21024)
-- Name: message fk_message_sender_principal_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT fk_message_sender_principal_id FOREIGN KEY (sender_id) REFERENCES public.principal(id);


--
-- TOC entry 2741 (class 2606 OID 21019)
-- Name: principal fk_principal_identity_id; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.principal
    ADD CONSTRAINT fk_principal_identity_id FOREIGN KEY (identity_id) REFERENCES public.identity(id);


-- Completed on 2018-07-11 12:45:19

--
-- PostgreSQL database dump complete
--

