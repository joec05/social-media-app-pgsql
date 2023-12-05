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
-- Name: bookmarks_list; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA bookmarks_list;


ALTER SCHEMA bookmarks_list OWNER TO postgres;

--
-- Name: comments_list; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA comments_list;


ALTER SCHEMA comments_list OWNER TO postgres;

--
-- Name: likes_list; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA likes_list;


ALTER SCHEMA likes_list OWNER TO postgres;

--
-- Name: posts_list; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA posts_list;


ALTER SCHEMA posts_list OWNER TO postgres;

--
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- Name: fetch_comment_bookmarks(text, text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_comment_bookmarks(commentid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select f.user_id as user_id from bookmarks_list.comments as f
	where comment_id = $1 and not is_muted_user($2, f.user_id, username, ip, port, password) 
	and not is_blocked_user($2, f.user_id, username, ip, port, password)
	and not is_blocked_user(f.user_id, $2, username, ip, port, password)
	and is_exists_user($2, f.user_id, username, ip, port, password)
	and not is_private_user($2, f.user_id, username, ip, port, password)
	offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_comment_bookmarks(commentid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_comment_comments(text, text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_comment_comments(commentid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(post_data json)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select row_to_json(p) as post_data from comments_list.comments_data as p
	where p.parent_post_id = $1 and p.deleted = false 
	and not is_muted_user($2, p.sender, username, ip, port, password) 
	and not is_blocked_user($2, p.sender, username, ip, port, password)
	and not is_blocked_user(p.sender, $2, username, ip, port, password) 
	and not is_private_user($2, p.sender, username, ip, port, password)
	and is_exists_user($2, p.sender, username, ip, port, password)
	order by p.upload_time desc offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_comment_comments(commentid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_comment_engagements(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_comment_engagements(currentid text, commentid text) RETURNS TABLE(liked_by_current_id boolean, likes_count integer, bookmarked_by_current_id boolean, bookmarks_count integer, comments_count integer)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select 
		exists (select 1 from likes_list.comments where user_id = $1 and comment_id = $2) as liked_by_current_id,
		(select count(*)::integer from likes_list.comments where comment_id = $2) as likes_count,
		exists (select 1 from bookmarks_list.comments where user_id = $1 and comment_id = $2) as bookmarked_by_current_id,
		(select count(*)::integer from bookmarks_list.comments where comment_id = $2) as bookmarks_count,
		(select count(*)::integer from comments_list.comments_data where parent_post_id = $2 and deleted = false) as comments_count
	;
end;
$_$;


ALTER FUNCTION public.fetch_comment_engagements(currentid text, commentid text) OWNER TO postgres;

--
-- Name: fetch_comment_likes(text, text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_comment_likes(commentid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select f.user_id as user_id from likes_list.comments as f
	where comment_id = $1 and not is_muted_user($2, f.user_id, username, ip, port, password) 
	and not is_blocked_user($2, f.user_id, username, ip, port, password)
	and not is_blocked_user(f.user_id, $2, username, ip, port, password) 
	and is_exists_user($2, f.user_id, username, ip, port, password)
	and not is_private_user($2, f.user_id, username, ip, port, password)
	offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_comment_likes(commentid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_feed(text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_feed(currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(post_data json)
    LANGUAGE plpgsql
    AS $_$
declare 
users_profiles_path text := 'dbname=users_profiles user='||username||' hostaddr='||ip||' port='||port||' password='||password;
begin
	return query select fetched_post_data as post_data from
	(
		select row_to_json(p) as fetched_post_data, upload_time from posts_list.posts_data as p
		inner join dblink(users_profiles_path, 'select * from follow_users.follow_history') 
		f(following_id text, followed_id text, follow_time text) on following_id = $1
		where p.sender = followed_id and p.deleted = false 
		and not is_muted_user($1, p.sender, username, IP, PORT, password)
		
		union all
		
		select row_to_json(p) as fetched_post_data, upload_time from posts_list.posts_data as p
		where p.sender = $1 and p.deleted = false
		
		union all
		
		select row_to_json(p) as fetched_post_data, upload_time from comments_list.comments_data as p
		inner join dblink(users_profiles_path, 'select * from follow_users.follow_history') 
		f(following_id text, followed_id text, follow_time text) on following_id = $1
		where p.sender = followed_id and p.deleted = false 
		and not is_muted_user($1, p.sender, username, IP, PORT, password)
		
		union all
		
		select row_to_json(p) as fetched_post_data, upload_time from comments_list.comments_data as p
		where p.sender = $1 and p.deleted = false
	) as res order by res.upload_time desc offset $2 limit $3;
end;
$_$;


ALTER FUNCTION public.fetch_feed(currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_most_popular_posts(text, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_most_popular_posts(currentid text, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(post_data json)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query 
	SELECT row_to_json(p) from likes_list.posts as l
	inner join posts_list.posts_data p on p.post_id = l.post_id
	where not is_muted_user($1, p.sender, username, IP, PORT, password) 
	and not is_blocked_user($1, p.sender, username, IP, PORT, password)
	and not is_blocked_user(p.sender, $1, username, IP, PORT, password) 
	and is_exists_user($1, p.sender, username, IP, PORT, password)
	group by p.post_id
	order by count(l.post_id) desc offset 0 limit $2
	;
end;
$_$;


ALTER FUNCTION public.fetch_most_popular_posts(currentid text, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_post_bookmarks(text, text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_post_bookmarks(postid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select f.user_id as user_id from bookmarks_list.posts as f
	where post_id = $1 and not is_muted_user($2, f.user_id, username, ip, port, password)
	and not is_blocked_user($2, f.user_id, username, ip, port, password)
	and not is_blocked_user(f.user_id, $2, username, ip, port, password)
	and is_exists_user($2, f.user_id, username, ip, port, password)
	and not is_private_user($2, f.user_id, username, ip, port, password)
	offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_post_bookmarks(postid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_post_comments(text, text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_post_comments(postid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(post_data json)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select row_to_json(p) as post_data from comments_list.comments_data as p
	where p.parent_post_id = $1 and p.deleted = false 
	and not is_muted_user($2, p.sender, username, ip, port, password) 
	and not is_blocked_user($2, p.sender, username, ip, port, password)
	and not is_blocked_user(p.sender, $2, username, ip, port, password)
	and not is_private_user($2, p.sender, username, ip, port, password)
	and is_exists_user($2, p.sender, username, ip, port, password)
	order by p.upload_time desc offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_post_comments(postid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_post_engagements(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_post_engagements(currentid text, postid text) RETURNS TABLE(liked_by_current_id boolean, likes_count integer, bookmarked_by_current_id boolean, bookmarks_count integer, comments_count integer)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select 
		exists (select 1 from likes_list.posts where user_id = $1 and post_id = $2) as liked_by_current_id,
		(select count(*)::integer from likes_list.posts where post_id = $2) as likes_count,
		exists (select 1 from bookmarks_list.posts where user_id = $1 and post_id = $2) as bookmarked_by_current_id,
		(select count(*)::integer from bookmarks_list.posts where post_id = $2) as bookmarks_count,
		(select count(*)::integer from comments_list.comments_data where parent_post_id = $2 and deleted = false) as comments_count
	;
end;
$_$;


ALTER FUNCTION public.fetch_post_engagements(currentid text, postid text) OWNER TO postgres;

--
-- Name: fetch_post_likes(text, text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_post_likes(postid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(user_id text)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select f.user_id as user_id from likes_list.posts as f
	where post_id = $1 and not is_muted_user($2, f.user_id, username, ip, port, password)
	and not is_blocked_user($2, f.user_id, username, ip, port, password)
	and not is_blocked_user(f.user_id, $2, username, ip, port, password)
	and is_exists_user($2, f.user_id, username, ip, port, password)
	and not is_private_user($2, f.user_id, username, ip, port, password)
	offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_post_likes(postid text, currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_searched_comments(text, text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_searched_comments(currentid text, searchedtext text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(post_data json)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select row_to_json(p) as post_data from comments_list.comments_data as p
	where lower(p.content) like '%' || lower($2) || '%' and not is_muted_user($1, p.sender, username, ip, port, password)
	and not is_blocked_user($1, p.sender, username, ip, port, password)
	and not is_blocked_user(p.sender, $1, username, ip, port, password) 
	and not is_private_user($1, p.sender, username, ip, port, password)
	and is_exists_user($1, p.sender, username, ip, port, password)
	and p.deleted = false
	order by p.upload_time desc offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_searched_comments(currentid text, searchedtext text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_searched_posts(text, text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_searched_posts(currentid text, searchedtext text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(post_data json)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select row_to_json(p) as post_data from posts_list.posts_data as p
	where lower(p.content) like '%' || lower($2) || '%' and not is_muted_user($1, p.sender, username, ip, port, password)
	and not is_blocked_user($1, p.sender, username, ip, port, password)
	and not is_blocked_user(p.sender, $1, username, ip, port, password) 
	and not is_private_user($1, p.sender, username, ip, port, password)
	and is_exists_user($1, p.sender, username, ip, port, password)
	and p.deleted = false
	order by p.upload_time desc offset $3 limit $4;
end;
$_$;


ALTER FUNCTION public.fetch_searched_posts(currentid text, searchedtext text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

--
-- Name: fetch_user_bookmarks(text, integer, integer, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fetch_user_bookmarks(currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) RETURNS TABLE(post_data json)
    LANGUAGE plpgsql
    AS $_$
declare 
begin
	return query select fetched_post_data as post_data from
	(
		select row_to_json(f) as fetched_post_data, bookmarked_time from bookmarks_list.posts as p
		inner join posts_list.posts_data f(
			post_id, type, content, sender, upload_time, medias_datas, deleted
		) on f.post_id = p.post_id
		where p.user_id = $1 and not is_muted_user($1, p.sender, username, ip, port, password)
		and not is_blocked_user($1, p.sender, username, ip, port, password)
		and not is_blocked_user(p.sender, $1, username, ip, port, password)
		and not is_private_user($1, p.sender, username, ip, port, password)
		and is_exists_user($1, p.sender, username, ip, port, password) and f.deleted = false
		
		union all
		
		select row_to_json(f) as fetched_post_data, bookmarked_time from bookmarks_list.comments as p
		inner join comments_list.comments_data f(
			comment_id, type, content, sender, upload_time, medias_datas, parent_post_type, 
        	parent_post_id, parent_post_sender, deleted
		) on f.comment_id = p.comment_id
		where p.user_id = $1 and not is_muted_user($1, p.sender, username, ip, port, password)
		and not is_blocked_user($1, p.sender, username, ip, port, password)
		and not is_blocked_user(p.sender, $1, username, ip, port, password)
		and not is_private_user($1, p.sender, username, ip, port, password)
		and is_exists_user($1, p.sender, username, ip, port, password) and f.deleted = false
	) as res order by res.bookmarked_time desc offset $2 limit $3;
end;
$_$;


ALTER FUNCTION public.fetch_user_bookmarks(currentid text, currentlength integer, paginationlimit integer, username text, ip text, port integer, password text) OWNER TO postgres;

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

--
-- Name: is_private_user(text, text, text, text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_private_user(checkingid text, checkedid text, username text, ip text, port integer, password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare 
res bool;
users_profiles_path text := 'dbname=users_profiles user='||username||' hostaddr='||ip||' port='||port||' password='||password;
begin	
	if checkingid = checkedid then return false; end if;
	select exists (
		select * from dblink(users_profiles_path, 'select user_id, private from basic_data.user_profile') as pr(user_id text, private bool)        
		where pr.user_id = $2 and pr.private = true
	) into res;
	if res = false then return false; end if;
    select not exists (
		select * from dblink(users_profiles_path, 'select * from follow_users.follow_history') as f(following_id text, followed_id text, follow_time text)        
		where following_id = $1 and followed_id = $2
	) into res;
	return res;
end;
$_$;


ALTER FUNCTION public.is_private_user(checkingid text, checkedid text, username text, ip text, port integer, password text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comments; Type: TABLE; Schema: bookmarks_list; Owner: postgres
--

CREATE TABLE bookmarks_list.comments (
    user_id text NOT NULL,
    comment_id text NOT NULL,
    sender text NOT NULL,
    bookmarked_time text NOT NULL
);


ALTER TABLE bookmarks_list.comments OWNER TO postgres;

--
-- Name: posts; Type: TABLE; Schema: bookmarks_list; Owner: postgres
--

CREATE TABLE bookmarks_list.posts (
    user_id text NOT NULL,
    post_id text NOT NULL,
    sender text NOT NULL,
    bookmarked_time text NOT NULL
);


ALTER TABLE bookmarks_list.posts OWNER TO postgres;

--
-- Name: comments_data; Type: TABLE; Schema: comments_list; Owner: postgres
--

CREATE TABLE comments_list.comments_data (
    comment_id text NOT NULL,
    type text NOT NULL,
    content text NOT NULL,
    sender text NOT NULL,
    upload_time text NOT NULL,
    medias_datas text NOT NULL,
    parent_post_type text NOT NULL,
    parent_post_id text NOT NULL,
    parent_post_sender text NOT NULL,
    deleted boolean NOT NULL
);


ALTER TABLE comments_list.comments_data OWNER TO postgres;

--
-- Name: comments; Type: TABLE; Schema: likes_list; Owner: postgres
--

CREATE TABLE likes_list.comments (
    user_id text NOT NULL,
    comment_id text NOT NULL
);


ALTER TABLE likes_list.comments OWNER TO postgres;

--
-- Name: posts; Type: TABLE; Schema: likes_list; Owner: postgres
--

CREATE TABLE likes_list.posts (
    user_id text NOT NULL,
    post_id text NOT NULL
);


ALTER TABLE likes_list.posts OWNER TO postgres;

--
-- Name: posts_data; Type: TABLE; Schema: posts_list; Owner: postgres
--

CREATE TABLE posts_list.posts_data (
    post_id text NOT NULL,
    type text NOT NULL,
    content text NOT NULL,
    sender text NOT NULL,
    upload_time text NOT NULL,
    medias_datas text NOT NULL,
    deleted boolean NOT NULL
);


ALTER TABLE posts_list.posts_data OWNER TO postgres;

--
-- Data for Name: comments; Type: TABLE DATA; Schema: bookmarks_list; Owner: postgres
--

COPY bookmarks_list.comments (user_id, comment_id, sender, bookmarked_time) FROM stdin;
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	fd49fff4-1709-446a-8b64-0fa19f61aff3	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T18:47:58.773+07:00
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	3f3c1cb5-0e4b-41bb-ade1-3610e2e29f06	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-02T21:09:32.624+07:00
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	3f3c1cb5-0e4b-41bb-ade1-3610e2e29f06	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-02T21:36:38.049+07:00
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	5c07aa63-4e61-4f7e-93dd-fb3929ae44c2	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-02T21:36:45.708+07:00
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	c06e546c-409e-4c56-b830-76fa0b61025e	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-02T21:36:50.153+07:00
\.


--
-- Data for Name: posts; Type: TABLE DATA; Schema: bookmarks_list; Owner: postgres
--

COPY bookmarks_list.posts (user_id, post_id, sender, bookmarked_time) FROM stdin;
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2754c2ea-4dd4-4e1e-93eb-fd644f693fc5	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T14:53:33.054+07:00
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	4166e8ad-6218-4c02-9e58-5482df330fdf	f10d6d78-77ef-4cc5-a19a-11ca023e57a4	2023-11-26T18:56:52.149+07:00
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	ccf835e2-eea8-4055-942b-97bf13aba39e	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T21:15:02.688+07:00
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	b91bd8f6-2ccf-4eaa-946c-d14d21741547	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-02T21:09:29.715+07:00
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	b91bd8f6-2ccf-4eaa-946c-d14d21741547	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-02T21:36:36.290+07:00
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	11e4bfa7-73dd-47ed-a40f-dfe677fec679	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T21:33:32.165+07:00
\.


--
-- Data for Name: comments_data; Type: TABLE DATA; Schema: comments_list; Owner: postgres
--

COPY comments_list.comments_data (comment_id, type, content, sender, upload_time, medias_datas, parent_post_type, parent_post_id, parent_post_sender, deleted) FROM stdin;
ee2e54c1-5ea4-4089-8f1d-05544d452e2c	comment	pk2	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T06:56:18.459Z	[]	post	33528665-7649-4de4-b973-a82c33315e78	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	f
fd49fff4-1709-446a-8b64-0fa19f61aff3	comment	ok3	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T06:56:23.405Z	[]	comment	d7f75f76-c88b-491a-9626-39412853bd6f	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	f
842b31cc-f388-4fd8-a77a-96e533cee06c	comment	lork	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T06:56:28.557Z	[]	comment	fd49fff4-1709-446a-8b64-0fa19f61aff3	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	f
d7f75f76-c88b-491a-9626-39412853bd6f	comment	ok2	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T06:56:10.616Z	[]	post	2754c2ea-4dd4-4e1e-93eb-fd644f693fc5	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	t
c8110200-6d10-4670-888d-a802ac96e046	comment	pep talk	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-30T13:10:20.581Z	[]	post	7e801c97-2dd2-4344-bc06-2a9bf3756428	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	f
4552de13-3004-408f-b9e8-0127b6382c96	comment	frocg	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-30T13:10:59.792Z	[]	post	3abb1ba1-e835-4625-9832-5cea326e617b	f10d6d78-77ef-4cc5-a19a-11ca023e57a4	f
c06e546c-409e-4c56-b830-76fa0b61025e	comment	hutuer	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-30T13:11:25.657Z	[]	post	3abb1ba1-e835-4625-9832-5cea326e617b	f10d6d78-77ef-4cc5-a19a-11ca023e57a4	f
5c07aa63-4e61-4f7e-93dd-fb3929ae44c2	comment	pam	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-30T13:12:02.177Z	[]	comment	c06e546c-409e-4c56-b830-76fa0b61025e	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	f
1dc772f5-a257-4009-895c-1178640d21b7	comment	exactly bro	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-30T13:39:24.509Z	[]	post	3abb1ba1-e835-4625-9832-5cea326e617b	f10d6d78-77ef-4cc5-a19a-11ca023e57a4	f
3f3c1cb5-0e4b-41bb-ade1-3610e2e29f06	comment	wow	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-30T13:39:39.042Z	[]	comment	1dc772f5-a257-4009-895c-1178640d21b7	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	f
\.


--
-- Data for Name: comments; Type: TABLE DATA; Schema: likes_list; Owner: postgres
--

COPY likes_list.comments (user_id, comment_id) FROM stdin;
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	fd49fff4-1709-446a-8b64-0fa19f61aff3
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	ee2e54c1-5ea4-4089-8f1d-05544d452e2c
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	3f3c1cb5-0e4b-41bb-ade1-3610e2e29f06
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	1dc772f5-a257-4009-895c-1178640d21b7
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	5c07aa63-4e61-4f7e-93dd-fb3929ae44c2
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	c06e546c-409e-4c56-b830-76fa0b61025e
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	c06e546c-409e-4c56-b830-76fa0b61025e
\.


--
-- Data for Name: posts; Type: TABLE DATA; Schema: likes_list; Owner: postgres
--

COPY likes_list.posts (user_id, post_id) FROM stdin;
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2754c2ea-4dd4-4e1e-93eb-fd644f693fc5
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	10e95832-6762-4bf3-9d0d-1de6047111b8
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	00850e38-8fd2-42db-955f-a5b1d7eae9d4
f10d6d78-77ef-4cc5-a19a-11ca023e57a4	b91bd8f6-2ccf-4eaa-946c-d14d21741547
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	3abb1ba1-e835-4625-9832-5cea326e617b
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	11e4bfa7-73dd-47ed-a40f-dfe677fec679
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	b7b488ea-de39-46c6-bb97-9d09141ac75c
ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	b91bd8f6-2ccf-4eaa-946c-d14d21741547
\.


--
-- Data for Name: posts_data; Type: TABLE DATA; Schema: posts_list; Owner: postgres
--

COPY posts_list.posts_data (post_id, type, content, sender, upload_time, medias_datas, deleted) FROM stdin;
2754c2ea-4dd4-4e1e-93eb-fd644f693fc5	post	ok	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T06:56:00.282Z	[]	f
33528665-7649-4de4-b973-a82c33315e78	post	pk	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T06:56:04.927Z	[]	f
ccf835e2-eea8-4055-942b-97bf13aba39e	post	@developer pakyi	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-26T11:31:16.754Z	[]	f
4166e8ad-6218-4c02-9e58-5482df330fdf	post	lo	f10d6d78-77ef-4cc5-a19a-11ca023e57a4	2023-11-26T11:56:47.095Z	[]	f
3abb1ba1-e835-4625-9832-5cea326e617b	post	guitar 	f10d6d78-77ef-4cc5-a19a-11ca023e57a4	2023-11-26T15:09:30.643Z	[{"mediaType":"image","url":"https://cloud.appwrite.io/v1/storage/buckets/64842b019dcd3146ae00/files/5a05c358-49f6-41fd-b965-7303174a0706/view?project=648336f2bc96857e5f14&mode=admin","storagePath":"5a05c358-49f6-41fd-b965-7303174a0706"}]	f
00850e38-8fd2-42db-955f-a5b1d7eae9d4	post	ffff	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-27T15:00:36.440Z	[]	f
a193f3b8-d78b-4b40-9a22-59a5ae9f6578	post		ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-27T15:06:19.604Z	[]	t
10e95832-6762-4bf3-9d0d-1de6047111b8	post	in the place 	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-27T23:51:58.531Z	[]	f
7e801c97-2dd2-4344-bc06-2a9bf3756428	post	PILLOWTALK	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-30T13:09:57.438Z	[]	f
04686e3e-c4b4-4219-8e51-085abd466aaf	post		cef86a8a-c06a-4812-ac3d-e9aee4fd7b19	2023-12-01T14:25:23.233Z	[{"mediaType":"video","url":"https://firebasestorage.googleapis.com/v0/b/flutter-social-media-app-7aac7.appspot.com/o/videos%2Fcef86a8a-c06a-4812-ac3d-e9aee4fd7b19%2F8de7dad5-3fab-4c27-83fa-83087dadf1cf?alt=media&token=742f505c-efa3-44ce-bbcf-edbf3609da4f","storagePath":"/cef86a8a-c06a-4812-ac3d-e9aee4fd7b19/8de7dad5-3fab-4c27-83fa-83087dadf1cf"}]	f
9b2ffa6e-55df-4e5e-ab54-0f9303e3528b	post	pol	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-11-30T14:45:18.663Z	[{"mediaType":"video","url":"https://firebasestorage.googleapis.com/v0/b/flutter-social-media-app-7aac7.appspot.com/o/videos%2Fea0ba766-8fab-42aa-ad3d-6cd5b0e18eac%2F91f81c72-a4ee-4adb-8298-6530889ccd26?alt=media&token=9543d5cc-6e63-4663-ba3c-195211bfc8f2","storagePath":"/ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac/91f81c72-a4ee-4adb-8298-6530889ccd26"}]	t
b91bd8f6-2ccf-4eaa-946c-d14d21741547	post	The UEFA Europa League (previously known as the UEFA Cup, abbreviated as UEL, or sometimes, UEFA EL) is an annual football club competition organised since 1971 by the Union of European Football Associations (UEFA) for eligible European football clubs. It is the second-tier competition of European c	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-02T13:59:04.620Z	[]	f
3bdd7123-e18b-4e7a-84a2-c2af27bce782	post	hello, my name is ioem.\n\nThe UEFA Europa League is an annual football club competition organised since 1971 by the Union of European Football Associations for eligible European football clubs. It is the 	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T09:20:21.264Z	[]	f
5e290c95-4dc2-4a22-8ea8-d7a9db13a68c	post	The UEFA Europa League is an annual football club competition organised since 1971 by the Union of European Football Associations for eligible European football clubs. It is the \n\nThe UEFA Europa League is an annual football club competition organised since 1971 by the Union of European Football Ass	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T11:16:16.162Z	[{"mediaType":"image","url":"https://cloud.appwrite.io/v1/storage/buckets/64842b019dcd3146ae00/files/1afdb1b1-6ac8-4a3a-84b7-f681944effe0/view?project=648336f2bc96857e5f14&mode=admin","storagePath":"1afdb1b1-6ac8-4a3a-84b7-f681944effe0"}]	f
1dc74b2c-b8a6-49ef-befb-0b0a6e5db294	post	this is a posr	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T11:39:40.538Z	[]	f
11e4bfa7-73dd-47ed-a40f-dfe677fec679	post	bencong but they t\n\n#one\n\n#two\n\n#three\n\n#four\n\n#five	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T14:26:54.530Z	[]	f
cd6a7c94-7c9d-4851-9355-aa3c057da7c7	post	#two is 2	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T14:51:59.367Z	[]	f
7bbed87b-185b-484c-b234-df1b36820a2b	post	#OneDirection is best band ever	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T14:53:42.559Z	[]	f
b7b488ea-de39-46c6-bb97-9d09141ac75c	post	#Pillowtalk is best song ever	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T14:53:57.582Z	[]	f
fe8adbfd-7f30-47be-8853-9309e8565032	post	#DuskTillDawn is iconic	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T14:54:16.420Z	[]	f
c21e6926-fbf2-4aaa-83f9-13ae2cce7c0e	post	#Westlife is nostalgic	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T14:54:27.285Z	[]	f
f3bfd6c9-01a1-4710-9c6e-3a466f18fbf9	post	#Eminem is king of rap	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-03T14:54:41.399Z	[]	f
7abd34f4-9908-40ca-8d43-6ba3118c7ecb	post	okay	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-04T12:57:51.409Z	[{"mediaType":"image","url":"https://cloud.appwrite.io/v1/storage/buckets/64842b019dcd3146ae00/files/21f58fdd-ab18-4dd8-ada2-f49b4ae9b22a/view?project=648336f2bc96857e5f14&mode=admin","storagePath":"21f58fdd-ab18-4dd8-ada2-f49b4ae9b22a"},{"mediaType":"image","url":"https://cloud.appwrite.io/v1/storage/buckets/64842b019dcd3146ae00/files/7460e7a3-cdd5-4560-b51d-217e7f6f8e9b/view?project=648336f2bc96857e5f14&mode=admin","storagePath":"7460e7a3-cdd5-4560-b51d-217e7f6f8e9b"}]	f
3184c6dc-45e7-4cc9-b1bd-acc560753577	post	lol dfmm	ea0ba766-8fab-42aa-ad3d-6cd5b0e18eac	2023-12-04T13:29:45.081Z	[{"mediaType":"image","url":"https://cloud.appwrite.io/v1/storage/buckets/64842b019dcd3146ae00/files/db069e0c-7933-4964-b657-dd87a70a22e7/view?project=648336f2bc96857e5f14&mode=admin","storagePath":"db069e0c-7933-4964-b657-dd87a70a22e7"},{"mediaType":"image","url":"https://cloud.appwrite.io/v1/storage/buckets/64842b019dcd3146ae00/files/f30033a1-7e91-4673-a043-d146bf9eee56/view?project=648336f2bc96857e5f14&mode=admin","storagePath":"f30033a1-7e91-4673-a043-d146bf9eee56"}]	f
\.


--
-- Name: comments bookmarks_list_comments_constraints; Type: CONSTRAINT; Schema: bookmarks_list; Owner: postgres
--

ALTER TABLE ONLY bookmarks_list.comments
    ADD CONSTRAINT bookmarks_list_comments_constraints UNIQUE (user_id, comment_id);


--
-- Name: posts bookmarks_list_posts_constraints; Type: CONSTRAINT; Schema: bookmarks_list; Owner: postgres
--

ALTER TABLE ONLY bookmarks_list.posts
    ADD CONSTRAINT bookmarks_list_posts_constraints UNIQUE (user_id, post_id);


--
-- Name: comments_data comments_data_constraints; Type: CONSTRAINT; Schema: comments_list; Owner: postgres
--

ALTER TABLE ONLY comments_list.comments_data
    ADD CONSTRAINT comments_data_constraints UNIQUE (comment_id);


--
-- Name: comments likes_list_comments_constraints; Type: CONSTRAINT; Schema: likes_list; Owner: postgres
--

ALTER TABLE ONLY likes_list.comments
    ADD CONSTRAINT likes_list_comments_constraints UNIQUE (user_id, comment_id);


--
-- Name: posts likes_list_posts_constraints; Type: CONSTRAINT; Schema: likes_list; Owner: postgres
--

ALTER TABLE ONLY likes_list.posts
    ADD CONSTRAINT likes_list_posts_constraints UNIQUE (user_id, post_id);


--
-- Name: posts_data posts_data_pkey; Type: CONSTRAINT; Schema: posts_list; Owner: postgres
--

ALTER TABLE ONLY posts_list.posts_data
    ADD CONSTRAINT posts_data_pkey PRIMARY KEY (post_id);


--
-- Name: posts_data posts_list_constraints; Type: CONSTRAINT; Schema: posts_list; Owner: postgres
--

ALTER TABLE ONLY posts_list.posts_data
    ADD CONSTRAINT posts_list_constraints UNIQUE (post_id);


--
-- PostgreSQL database dump complete
--

