--
-- PostgreSQL database dump
--

-- Dumped from database version 16rc1
-- Dumped by pg_dump version 16rc1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hashtags; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA hashtags;


ALTER SCHEMA hashtags OWNER to postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: hashtags_list; Type: TABLE; Schema: hashtags; Owner: postgres
--

CREATE TABLE hashtags.hashtags_list (
    hashtag text NOT NULL,
    hashtag_count integer NOT NULL
);


ALTER TABLE hashtags.hashtags_list OWNER TO postgres;

--
-- Data for Name: hashtags_list; Type: TABLE DATA; Schema: hashtags; Owner: postgres
--

COPY hashtags.hashtags_list (hashtag, hashtag_count) FROM stdin;
\.


--
-- Name: hashtags_list hashtag_constraint; Type: CONSTRAINT; Schema: hashtags; Owner: postgres
--

ALTER TABLE ONLY hashtags.hashtags_list
    ADD CONSTRAINT hashtag_constraint UNIQUE (hashtag);


--
-- Name: hashtags_list hashtags_list_pkey; Type: CONSTRAINT; Schema: hashtags; Owner: postgres
--

ALTER TABLE ONLY hashtags.hashtags_list
    ADD CONSTRAINT hashtags_list_pkey PRIMARY KEY (hashtag);


--
-- PostgreSQL database dump complete
--

