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
-- Name: basic_data; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA basic_data;


ALTER SCHEMA basic_data OWNER TO postgres;

--
-- Name: blocked_users; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA blocked_users;


ALTER SCHEMA blocked_users OWNER TO postgres;

--
-- Name: follow_requests_users; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA follow_requests_users;


ALTER SCHEMA follow_requests_users OWNER TO postgres;

--
-- Name: follow_users; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA follow_users;


ALTER SCHEMA follow_users OWNER TO postgres;

--
-- Name: muted_users; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA muted_users;


ALTER SCHEMA muted_users OWNER TO postgres;

--
-- Name: sensitive_data; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA sensitive_data;


ALTER SCHEMA sensitive_data OWNER TO postgres;

--
-- Name: fetch_follow_requests_from(text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_follow_requests_from(currentid text, currentlength integer, paginationlimit integer) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select requested_id from follow_requests_users.follow_request_history as f
	where f.requesting_id = $1 and not is_blocked_user($1, f.requested_id)
	and not is_blocked_user(f.requested_id, $1) and is_exists_user($1, f.requested_id)
	order by f.request_time desc offset $2 limit $3;
end;
$_$;


ALTER FUNCTION public.fetch_follow_requests_from(currentid text, currentlength integer, paginationlimit integer) OWNER TO postgres;

--
-- Name: fetch_follow_requests_to(text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_follow_requests_to(currentid text, currentlength integer, paginationlimit integer) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select requesting_id from follow_requests_users.follow_request_history as f
	where f.requested_id = $1 and not is_blocked_user($1, f.requesting_id)
	and not is_blocked_user(f.requesting_id, $1) and is_exists_user($1, f.requesting_id)
	order by f.request_time desc offset $2 limit $3;
end;
$_$;


ALTER FUNCTION public.fetch_follow_requests_to(currentid text, currentlength integer, paginationlimit integer) OWNER TO postgres;

--
-- Name: fetch_most_popular_users(text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_most_popular_users(currentid text, paginationlimit integer) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query 
	SELECT followed_id from follow_users.follow_history as f
	where not is_blocked_user($1, f.followed_id)
	and not is_blocked_user(f.followed_id, $1) and is_exists_user($1, f.followed_id)
	group by f.followed_id
	order by count(f.followed_id) offset 0 limit $2
	;
end;
$_$;


ALTER FUNCTION public.fetch_most_popular_users(currentid text, paginationlimit integer) OWNER TO postgres;

--
-- Name: fetch_searched_add_to_group_users(text, text, text[], integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_searched_add_to_group_users(searchedtext text, currentid text, recipients text[], currentlength integer, paginationlimit integer) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select f.user_id as user_id from basic_data.user_profile as f
	where (f.name LIKE '%' || LOWER($1) || '%' or f.username LIKE '%' || LOWER($1) || '%')
	and f.user_id != $2
	and not is_blocked_user($2, f.user_id) and not is_blocked_user(f.user_id, $2)
	and is_exists_user($2, f.user_id) and not f.user_id = ANY(recipients)
	offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_searched_add_to_group_users(searchedtext text, currentid text, recipients text[], currentlength integer, paginationlimit integer) OWNER TO postgres;

--
-- Name: fetch_searched_chat_users(text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_searched_chat_users(searchedtext text, currentid text, currentlength integer, paginationlimit integer) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select f.user_id as user_id from basic_data.user_profile as f
	where (f.name LIKE '%' || LOWER($1) || '%' or f.username LIKE '%' || LOWER($1) || '%')
	and f.user_id != $2
	and not is_blocked_user($2, f.user_id) and not is_blocked_user(f.user_id, $2)
	and is_exists_user($2, f.user_id)
	offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_searched_chat_users(searchedtext text, currentid text, currentlength integer, paginationlimit integer) OWNER TO postgres;

--
-- Name: fetch_searched_tag_users(text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_searched_tag_users(searchedtext text, currentid text, currentlength integer, paginationlimit integer) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select f.user_id as user_id from basic_data.user_profile as f
	where (f.name LIKE '%' || LOWER($1) || '%' or f.username LIKE '%' || LOWER($1) || '%')
	and not is_blocked_user($2, f.user_id) and not is_blocked_user(f.user_id, $2)
	and is_exists_user($2, f.user_id)
	offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_searched_tag_users(searchedtext text, currentid text, currentlength integer, paginationlimit integer) OWNER TO postgres;

--
-- Name: fetch_user_followers(text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_user_followers(userid text, currentid text, currentlength integer, paginationlimit integer) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select following_id from follow_users.follow_history as f
	where followed_id = $1 and not is_blocked_user($2, f.following_id)
	and not is_blocked_user(f.following_id, $2) and is_exists_user($2, f.following_id)
	order by f.follow_time desc offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_user_followers(userid text, currentid text, currentlength integer, paginationlimit integer) OWNER TO postgres;

--
-- Name: fetch_user_following(text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_user_following(userid text, currentid text, currentlength integer, paginationlimit integer) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select followed_id from follow_users.follow_history as f
	where following_id = $1 and not is_blocked_user($2, f.followed_id)
	and not is_blocked_user(f.followed_id, $2) and is_exists_user($2, f.followed_id)
	order by f.follow_time desc offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_user_following(userid text, currentid text, currentlength integer, paginationlimit integer) OWNER TO postgres;

--
-- Name: is_blocked_user(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_blocked_user(checkingid text, checkedid text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare 
res bool;
begin	
	if checkingid = checkedid then return false; end if;
	select exists into res(
		select * from blocked_users.block_history as b
		where b.user_id = $1 and b.blocked_id = $2
	);
	return res;
end;
$_$;


ALTER FUNCTION public.is_blocked_user(checkingid text, checkedid text) OWNER TO postgres;

--
-- Name: is_exists_user(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_exists_user(checkingid text, checkedid text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare 
res bool;
begin
	if checkingid = checkedid then return true; end if;
	select exists into res(
		select user_id, deleted, suspended from basic_data.user_profile
		where user_id = $2 and deleted = false and suspended = false
	);
	return res;
end;
$_$;


ALTER FUNCTION public.is_exists_user(checkingid text, checkedid text) OWNER TO postgres;

--
-- Name: is_muted_user(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_muted_user(checkingid text, checkedid text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare 
res bool;
begin
	if checkingid = checkedid then return false; end if;
	select exists into res(
		select * from muted_users.mute_history as m 
		where m.user_id = $1 and m.muted_id = $2
	);
	return res;
end;
$_$;


ALTER FUNCTION public.is_muted_user(checkingid text, checkedid text) OWNER TO postgres;

--
-- Name: is_private_user(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_private_user(checkingid text, checkedid text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare 
res bool;
begin
	if checkingid = checkedid then return false; end if;
	select exists into res(
		select user_id, private from basic_data.user_profile as pr
		where pr.user_id = $2 and pr.private = true
	);
	if res = false then return false; end if;
	select not exists into res(
		select 1 from follow_users.follow_history 
		where following_id = $1 and followed_id = $2
	);
	return res;
end;
$_$;


ALTER FUNCTION public.is_private_user(checkingid text, checkedid text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: user_profile; Type: TABLE; Schema: basic_data; Owner: postgres
--

CREATE TABLE basic_data.user_profile (
    user_id text NOT NULL,
    name text NOT NULL,
    username text NOT NULL,
    email text NOT NULL,
    profile_picture_link text NOT NULL,
    date_joined text NOT NULL,
    birth_date text NOT NULL,
    bio text NOT NULL,
    private boolean NOT NULL,
    verified boolean NOT NULL,
    suspended boolean NOT NULL,
    deleted boolean NOT NULL
);


ALTER TABLE basic_data.user_profile OWNER TO postgres;

--
-- Name: block_history; Type: TABLE; Schema: blocked_users; Owner: postgres
--

CREATE TABLE blocked_users.block_history (
    user_id text NOT NULL,
    blocked_id text NOT NULL
);


ALTER TABLE blocked_users.block_history OWNER TO postgres;

--
-- Name: follow_request_history; Type: TABLE; Schema: follow_requests_users; Owner: postgres
--

CREATE TABLE follow_requests_users.follow_request_history (
    requesting_id text NOT NULL,
    requested_id text NOT NULL,
    request_time text NOT NULL
);


ALTER TABLE follow_requests_users.follow_request_history OWNER TO postgres;

--
-- Name: follow_history; Type: TABLE; Schema: follow_users; Owner: postgres
--

CREATE TABLE follow_users.follow_history (
    following_id text NOT NULL,
    followed_id text NOT NULL,
    follow_time text NOT NULL
);


ALTER TABLE follow_users.follow_history OWNER TO postgres;

--
-- Name: mute_history; Type: TABLE; Schema: muted_users; Owner: postgres
--

CREATE TABLE muted_users.mute_history (
    user_id text NOT NULL,
    muted_id text NOT NULL
);


ALTER TABLE muted_users.mute_history OWNER TO postgres;

--
-- Name: user_password; Type: TABLE; Schema: sensitive_data; Owner: postgres
--

CREATE TABLE sensitive_data.user_password (
    user_id text NOT NULL,
    password text NOT NULL
);


ALTER TABLE sensitive_data.user_password OWNER TO postgres;

--
-- Data for Name: user_profile; Type: TABLE DATA; Schema: basic_data; Owner: postgres
--

COPY basic_data.user_profile (user_id, name, username, email, profile_picture_link, date_joined, birth_date, bio, private, verified, suspended, deleted) FROM stdin;
\.


--
-- Data for Name: block_history; Type: TABLE DATA; Schema: blocked_users; Owner: postgres
--

COPY blocked_users.block_history (user_id, blocked_id) FROM stdin;
\.


--
-- Data for Name: follow_request_history; Type: TABLE DATA; Schema: follow_requests_users; Owner: postgres
--

COPY follow_requests_users.follow_request_history (requesting_id, requested_id, request_time) FROM stdin;
\.


--
-- Data for Name: follow_history; Type: TABLE DATA; Schema: follow_users; Owner: postgres
--

COPY follow_users.follow_history (following_id, followed_id, follow_time) FROM stdin;
\.


--
-- Data for Name: mute_history; Type: TABLE DATA; Schema: muted_users; Owner: postgres
--

COPY muted_users.mute_history (user_id, muted_id) FROM stdin;
\.


--
-- Data for Name: user_password; Type: TABLE DATA; Schema: sensitive_data; Owner: postgres
--

COPY sensitive_data.user_password (user_id, password) FROM stdin;
\.


--
-- Name: user_profile users_profile_constraints; Type: CONSTRAINT; Schema: basic_data; Owner: postgres
--

ALTER TABLE ONLY basic_data.user_profile
    ADD CONSTRAINT users_profile_constraints UNIQUE (user_id);


--
-- Name: block_history block_history_constraints; Type: CONSTRAINT; Schema: blocked_users; Owner: postgres
--

ALTER TABLE ONLY blocked_users.block_history
    ADD CONSTRAINT block_history_constraints UNIQUE (user_id, blocked_id);


--
-- Name: follow_request_history follow_request_history_constraints; Type: CONSTRAINT; Schema: follow_requests_users; Owner: postgres
--

ALTER TABLE ONLY follow_requests_users.follow_request_history
    ADD CONSTRAINT follow_request_history_constraints UNIQUE (requesting_id, requested_id);


--
-- Name: follow_history follow_history_constraints; Type: CONSTRAINT; Schema: follow_users; Owner: postgres
--

ALTER TABLE ONLY follow_users.follow_history
    ADD CONSTRAINT follow_history_constraints UNIQUE (following_id, followed_id);


--
-- Name: mute_history mute_history_constraints; Type: CONSTRAINT; Schema: muted_users; Owner: postgres
--

ALTER TABLE ONLY muted_users.mute_history
    ADD CONSTRAINT mute_history_constraints UNIQUE (user_id, muted_id);


--
-- Name: user_password user_password_constraints; Type: CONSTRAINT; Schema: sensitive_data; Owner: postgres
--

ALTER TABLE ONLY sensitive_data.user_password
    ADD CONSTRAINT user_password_constraints UNIQUE (user_id);


--
-- PostgreSQL database dump complete
--

