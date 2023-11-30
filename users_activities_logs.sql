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
-- Name: notifications_data; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA notifications_data;


ALTER SCHEMA notifications_data OWNER to postgres;

--
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- Name: fetch_user_notifications(text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_user_notifications(currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(notification_data json)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select row_to_json(p) as notification_data from notifications_data.notifications_history as p
	where p.recipient = $1 and not is_muted_user($1, p.sender, username, IP, PORT, password) 
	and not is_blocked_user($1, p.sender, username, IP, PORT, password)
	and not is_blocked_user(p.sender, $1, username, IP, PORT, password) 
	and is_exists_user($1, p.sender, username, IP, PORT, password)
	order by p.notified_time desc offset $2 limit $3;
end;
$_$;


ALTER FUNCTION public.fetch_user_notifications(currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: is_blocked_user(text, text, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_blocked_user(checkingid text, checkedid text, username text, ip text, port integer, password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare 
res bool;
users_profiles_path text := 'dbname=users_profiles user='||username||' hostaddr='||ip||' port='||port||' password='||password;
begin	
	if checkingid = checkedid then return false; end if;
	select exists (
		select * from dblink(users_profiles_path, 'select * from blocked_users.block_history') as b(user_id text, blocked_id text)        
		where b.user_id = $1 and b.blocked_id = $2
	) into res;
	return res;
end;
$_$;


ALTER FUNCTION public.is_blocked_user(checkingid text, checkedid text, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: is_exists_user(text, text, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_exists_user(checkingid text, checkedid text, username text, ip text, port integer, password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare 
res bool;
users_profiles_path text := 'dbname=users_profiles user='||username||' hostaddr='||ip||' port='||port||' password='||password;
begin	
	if checkingid = checkedid then return true; end if;
	select exists (
		select * from dblink(users_profiles_path, 'select user_id, deleted, suspended from basic_data.user_profile') as pr(user_id text, deleted bool, suspended bool)        
		where pr.user_id = $2 and pr.deleted = false and pr.suspended = false
	) into res;
	return res;
end;
$_$;


ALTER FUNCTION public.is_exists_user(checkingid text, checkedid text, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: is_muted_user(text, text, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_muted_user(checkingid text, checkedid text, username text, ip text, port integer, password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare 
res bool;
users_profiles_path text := 'dbname=users_profiles user='||username||' hostaddr='||ip||' port='||port||' password='||password;
begin	
	if checkingid = checkedid then return false; end if;
	select exists (
		select * from dblink(users_profiles_path, 'select * from muted_users.mute_history') as m(user_id text, muted_id text)
		where m.user_id = $1 and m.muted_id = $2
	) into res;
	return res;
end;
$_$;


ALTER FUNCTION public.is_muted_user(checkingid text, checkedid text, username text, ip text, port integer, password text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: notifications_history; Type: TABLE; Schema: notifications_data; Owner: postgres
--

CREATE TABLE notifications_data.notifications_history (
    type text NOT NULL,
    sender text NOT NULL,
    recipient text NOT NULL,
    referenced_post_id text NOT NULL,
    referenced_post_type text NOT NULL,
    notified_time text NOT NULL
);


ALTER TABLE notifications_data.notifications_history OWNER TO postgres;

--
-- Data for Name: notifications_history; Type: TABLE DATA; Schema: notifications_data; Owner: postgres
--

COPY notifications_data.notifications_history (type, sender, recipient, referenced_post_id, referenced_post_type, notified_time) FROM stdin;
\.


--
-- PostgreSQL database dump complete
--

