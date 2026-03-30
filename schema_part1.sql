--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--




--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--



--
-- Name: attempt_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.attempt_status AS ENUM (
    'in_progress',
    'submitted',
    'abandoned',
    'auto_submitted'
);



--
-- Name: question_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.question_type AS ENUM (
    'single_correct',
    'multiple_correct',
    'true_false'
);



--
-- Name: test_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.test_status AS ENUM (
    'draft',
    'published',
    'archived'
);



--
-- Name: check_username_available(text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION public.check_username_available(p_username text, p_user_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

  select not exists (

    select 1

    from   public.profiles

    where  username = p_username

      and  id <> p_user_id

  );

$$;



--
-- Name: get_candidate_home_stats(uuid); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE OR REPLACE FUNCTION public.get_candidate_home_stats(p_profile_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_profile RECORD;
    v_now TIMESTAMPTZ := NOW();
    v_total_tests BIGINT := 0;
    v_live_tests BIGINT := 0;
    v_upcoming_tests BIGINT := 0;
    v_completed_tests BIGINT := 0;
BEGIN
    -- Fetch the candidate profile
    SELECT * INTO v_profile 
    FROM public.candidate_profiles 
    WHERE profile_id = p_profile_id;

    -- If profile exists, fetch counts
    IF v_profile.profile_id IS NOT NULL AND v_profile.institute_id IS NOT NULL THEN
        -- Total published tests for this institute
        SELECT count(*) INTO v_total_tests
        FROM public.tests
        WHERE status = 'published' AND institute_id = v_profile.institute_id;

        -- Live tests
        SELECT count(*) INTO v_live_tests
        FROM public.tests
        WHERE status = 'published' 
          AND institute_id = v_profile.institute_id
          AND (available_from IS NULL OR available_from <= v_now)
          AND (available_until IS NULL OR available_until >= v_now);

        -- Upcoming tests
        SELECT count(*) INTO v_upcoming_tests
        FROM public.tests
        WHERE status = 'published' 
          AND institute_id = v_profile.institute_id
          AND available_from > v_now;

        -- Completed attempts by this student
        SELECT count(*) INTO v_completed_tests
        FROM public.test_attempts
        WHERE student_id = p_profile_id AND status = 'submitted';
    END IF;

    RETURN jsonb_build_object(
        'profile', (CASE WHEN v_profile.profile_id IS NOT NULL THEN row_to_json(v_profile) ELSE NULL END),
        'stats', jsonb_build_object(
            'total_tests', v_total_tests,
            'live_tests', v_live_tests,
            'upcoming_tests', v_upcoming_tests,
            'completed_tests', v_completed_tests
        )
    );
END;
$$;



--
-- Name: get_institute_home_stats(uuid); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE OR REPLACE FUNCTION public.get_institute_home_stats(p_profile_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_profile RECORD;
    v_now TIMESTAMPTZ := NOW();
    v_total_tests BIGINT := 0;
    v_live_tests BIGINT := 0;
    v_upcoming_tests BIGINT := 0;
    v_past_tests BIGINT := 0;
    v_draft_tests BIGINT := 0;
    v_total_attempts BIGINT := 0;
BEGIN
    -- Fetch the institute profile
    SELECT * INTO v_profile 
    FROM public.institute_profiles 
    WHERE profile_id = p_profile_id;

    -- Fetch counts
    -- Total tests
    SELECT count(*) INTO v_total_tests
    FROM public.tests
    WHERE institute_id = p_profile_id;

    -- Live tests
    SELECT count(*) INTO v_live_tests
    FROM public.tests
    WHERE institute_id = p_profile_id 
      AND status = 'published' 
      AND (available_from IS NULL OR available_from <= v_now)
      AND (available_until IS NULL OR available_until >= v_now);

    -- Upcoming tests
    SELECT count(*) INTO v_upcoming_tests
    FROM public.tests
    WHERE institute_id = p_profile_id 
      AND status = 'published'
      AND available_from > v_now;

    -- Past tests
    SELECT count(*) INTO v_past_tests
    FROM public.tests
    WHERE institute_id = p_profile_id 
      AND status = 'published'
      AND available_until < v_now;

    -- Draft tests
    SELECT count(*) INTO v_draft_tests
    FROM public.tests
    WHERE institute_id = p_profile_id 
      AND status = 'draft';

    -- Total attempts for this institute
    SELECT count(*) INTO v_total_attempts
    FROM public.test_attempts ta
    JOIN public.tests t ON ta.test_id = t.id
    WHERE t.institute_id = p_profile_id;

    RETURN jsonb_build_object(
        'profile', (CASE WHEN v_profile.profile_id IS NOT NULL THEN row_to_json(v_profile) ELSE NULL END),
        'stats', jsonb_build_object(
            'total_tests', v_total_tests,
            'live_tests', v_live_tests,
            'upcoming_tests', v_upcoming_tests,
            'past_tests', v_past_tests,
            'draft_tests', v_draft_tests,
            'total_attempts', v_total_attempts
        )
    );
END;
$$;



--
-- Name: grade_attempt(uuid); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE OR REPLACE FUNCTION public.grade_attempt(p_attempt_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_test_pass_pct numeric(5,2);
    v_test_id       uuid;
    v_answer        record;
    v_correct_ids   uuid[];
    v_selected_ids  uuid[];
    v_is_correct    boolean;
    v_marks         numeric(5,2);
    v_total         numeric(7,2) := 0;
    v_scored        numeric(7,2) := 0;
    v_passed        boolean := null;
BEGIN
    SELECT test_id INTO v_test_id
    FROM public.test_attempts
    WHERE id = p_attempt_id AND status IN ('in_progress', 'auto_submitted');

    IF v_test_id IS NULL THEN
        RAISE EXCEPTION 'Attempt not found or already submitted'
          USING errcode = 'no_data_found';
    END IF;

    SELECT 
        t.pass_percentage,
        COALESCE((SELECT sum(marks) FROM public.questions WHERE test_id = t.id), 0)
    INTO v_test_pass_pct, v_total
    FROM public.tests t
    WHERE t.id = v_test_id;

    FOR v_answer IN
        SELECT aa.id, aa.question_id, aa.selected_option_ids, q.marks, q.negative_marks
        FROM public.attempt_answers aa
        JOIN public.questions q ON q.id = aa.question_id
        WHERE aa.attempt_id = p_attempt_id
    LOOP
        SELECT array_agg(id ORDER BY id) INTO v_correct_ids
        FROM public.options
        WHERE question_id = v_answer.question_id AND is_correct = TRUE;

        SELECT array_agg(x ORDER BY x) INTO v_selected_ids
        FROM UNNEST(v_answer.selected_option_ids) x;

        v_is_correct := (COALESCE(v_selected_ids, '{}') = COALESCE(v_correct_ids, '{}'));

        IF v_is_correct THEN
            v_marks := v_answer.marks;
        ELSIF ARRAY_LENGTH(v_selected_ids, 1) > 0 THEN
            v_marks := -ABS(v_answer.negative_marks);
        ELSE
            v_marks := 0;
        END IF;

        UPDATE public.attempt_answers
        SET is_correct    = v_is_correct,
            marks_awarded = v_marks,
            updated_at    = NOW()
        WHERE id = v_answer.id;

        v_scored := v_scored + v_marks;
    END LOOP;

    IF v_test_pass_pct IS NOT NULL AND v_total > 0 THEN
        v_passed := (v_scored / v_total) * 100 >= v_test_pass_pct;
    END IF;

    UPDATE public.test_attempts
    SET status       = CASE WHEN status = 'in_progress' THEN 'submitted'::attempt_status ELSE status END,
        submitted_at = COALESCE(submitted_at, NOW()),
        score        = v_scored,
        total_marks  = v_total,
        passed       = v_passed,
        updated_at   = NOW()
    WHERE id = p_attempt_id;
END;
$$;



--
-- Name: grade_attempt_v2(uuid, integer); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE OR REPLACE FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_test_pass_pct numeric(5,2);
    v_test_id       uuid;
    v_answer        record;
    v_correct_ids   uuid[];
    v_selected_ids  uuid[];
    v_is_correct    boolean;
    v_marks         numeric(5,2);
    v_total         numeric(7,2) := 0;
    v_scored        numeric(7,2) := 0;
    v_passed        boolean := null;
BEGIN
    -- 1. Update final time spent and check status
    UPDATE public.test_attempts
    SET time_spent_seconds = p_final_time_spent
    WHERE id = p_attempt_id
       AND student_id = auth.uid()
       AND status IN ('in_progress', 'auto_submitted')
    RETURNING test_id INTO v_test_id;

    IF v_test_id IS NULL THEN
        RETURN jsonb_build_object('error', 'Attempt not found or already submitted');
    END IF;

    -- 2. Get test pass criteria and sum of all question marks
    SELECT 
        t.pass_percentage,
        COALESCE((SELECT sum(marks) FROM public.questions WHERE test_id = t.id), 0)
    INTO v_test_pass_pct, v_total
    FROM public.tests t
    WHERE t.id = v_test_id;

    -- 3. Cycle through answers and update scores
    FOR v_answer IN
        SELECT aa.id, aa.question_id, aa.selected_option_ids, q.marks, q.negative_marks
        FROM public.attempt_answers aa
        JOIN public.questions q ON q.id = aa.question_id
        WHERE aa.attempt_id = p_attempt_id
    LOOP
        SELECT array_agg(id ORDER BY id) INTO v_correct_ids
        FROM public.options
        WHERE question_id = v_answer.question_id AND is_correct = TRUE;

        SELECT array_agg(x ORDER BY x) INTO v_selected_ids
        FROM UNNEST(v_answer.selected_option_ids) x;

        v_is_correct := (COALESCE(v_selected_ids, '{}') = COALESCE(v_correct_ids, '{}'));

        IF v_is_correct THEN
            v_marks := v_answer.marks;
        ELSIF ARRAY_LENGTH(v_selected_ids, 1) > 0 THEN
            v_marks := -ABS(v_answer.negative_marks);
        ELSE
            v_marks := 0;
        END IF;

        UPDATE public.attempt_answers
        SET is_correct    = v_is_correct,
            marks_awarded = v_marks,
            updated_at    = NOW()
        WHERE id = v_answer.id;

        v_scored := v_scored + v_marks;
    END LOOP;

    -- 4. Pass/Fail Decision
    IF v_test_pass_pct IS NOT NULL AND v_total > 0 THEN
        v_passed := (v_scored / v_total) * 100 >= v_test_pass_pct;
    END IF;

    -- 5. Finalize attempt
    UPDATE public.test_attempts
    SET status       = CASE WHEN status = 'in_progress' THEN 'submitted'::attempt_status ELSE status END,
        submitted_at = COALESCE(submitted_at, NOW()),
        score        = v_scored,
        total_marks  = v_total,
        passed       = v_passed,
        updated_at   = NOW()
    WHERE id = p_attempt_id;

    RETURN jsonb_build_object(
        'status', 'submitted',
        'test_id', v_test_id,
        'score', v_scored,
        'total_marks', v_total
    );
END;
$$;



--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  insert into public.profiles (id, email, account_type, display_name)
  values (
    new.id,
    new.email,
    'candidate',
    new.raw_user_meta_data->>'display_name'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;



--
-- Name: handle_session_sync(); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE OR REPLACE FUNCTION public.handle_session_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

BEGIN

  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN

    INSERT INTO public.user_sessions (id, user_id, created_at, updated_at, not_after, ip, user_agent, tag)

    VALUES (NEW.id, NEW.user_id, NEW.created_at, NEW.updated_at, NEW.not_after, NEW.ip, NEW.user_agent, NEW.tag)

    ON CONFLICT (id) DO UPDATE SET

      updated_at = EXCLUDED.updated_at,

      not_after = EXCLUDED.not_after,

      ip = EXCLUDED.ip,

      user_agent = EXCLUDED.user_agent;

  ELSIF (TG_OP = 'DELETE') THEN

    DELETE FROM public.user_sessions WHERE id = OLD.id;

  END IF;

  RETURN NULL;

END;

$$;



--
-- Name: init_test_attempt(uuid); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE OR REPLACE FUNCTION public.init_test_attempt(p_test_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile RECORD;
    v_test RECORD;
    v_existing_attempt RECORD;
    v_completed_count INT;
    v_saved_answers JSONB;
BEGIN
    -- 1. Authorization & Profile Check
    SELECT institute_id, profile_complete, profile_updated 
    INTO v_profile FROM public.candidate_profiles WHERE profile_id = v_user_id;
    
    IF v_profile IS NULL OR NOT COALESCE(v_profile.profile_complete, FALSE) OR NOT COALESCE(v_profile.profile_updated, FALSE) THEN
        RETURN jsonb_build_object('error', 'Profile incomplete');
    END IF;

    -- 2. Test Availability Check
    SELECT id, status, institute_id, time_limit_seconds, max_attempts, title
    INTO v_test FROM public.tests WHERE id = p_test_id;

    IF v_test IS NULL OR v_test.status != 'published' OR v_test.institute_id != v_profile.institute_id THEN
        RETURN jsonb_build_object('error', 'Test not available or invalid institute');
    END IF;

    -- 3. Check for existing in-progress attempt (Resume)
    SELECT id, started_at, expires_at, tab_switch_count 
    INTO v_existing_attempt
    FROM public.test_attempts 
    WHERE test_id = p_test_id AND student_id = v_user_id AND status = 'in_progress'
    ORDER BY created_at DESC LIMIT 1;

    IF v_existing_attempt IS NOT NULL THEN
        -- Check if expired server-side
        IF v_existing_attempt.expires_at IS NOT NULL AND v_existing_attempt.expires_at < NOW() THEN
            PERFORM public.grade_attempt(v_existing_attempt.id);
            RETURN jsonb_build_object('status', 'expired', 'test_id', p_test_id);
        END IF;

        -- Fetch saved answers for the resumed attempt
        SELECT jsonb_agg(jsonb_build_object(
            'question_id', question_id,
            'selected_option_ids', selected_option_ids
        )) INTO v_saved_answers
        FROM public.attempt_answers
        WHERE attempt_id = v_existing_attempt.id;

        RETURN jsonb_build_object(
            'status', 'resumed',
            'attempt', jsonb_build_object(
                'id', v_existing_attempt.id,
                'started_at', v_existing_attempt.started_at,
                'expires_at', v_existing_attempt.expires_at,
                'tab_switch_count', COALESCE(v_existing_attempt.tab_switch_count, 0)
            ),
            'saved_answers', COALESCE(v_saved_answers, '[]'::jsonb)
        );
    END IF;

    -- 4. Check Remaining Attempts
    SELECT count(*) INTO v_completed_count 
    FROM public.test_attempts 
    WHERE test_id = p_test_id AND student_id = v_user_id 
    AND status IN ('submitted', 'auto_submitted');

    IF v_completed_count >= v_test.max_attempts THEN
        RETURN jsonb_build_object('error', 'Max attempts reached (' || v_completed_count || '/' || v_test.max_attempts || ')');
    END IF;

    -- 5. Return Readiness
    RETURN jsonb_build_object(
        'status', 'ready',
        'completed_count', v_completed_count,
        'max_attempts', v_test.max_attempts
    );
END;
$$;



--
-- Name: revoke_session(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION public.revoke_session(p_session_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$

begin

  if not exists (

    select 1 from auth.sessions

    where id = p_session_id

      and user_id = auth.uid()

  ) then

    raise exception 'Session not found or does not belong to the current user'

      using errcode = 'insufficient_privilege';

  end if;



  delete from auth.sessions where id = p_session_id;

end;

$$;



--
-- Name: revoke_sessions_batch(uuid[]); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE OR REPLACE FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  DELETE FROM auth.sessions 
  WHERE id = ANY(p_session_ids) 
    AND user_id = auth.uid();
END;
$$;



--
-- Name: save_answer(uuid, uuid, uuid[], integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION public.save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer DEFAULT 0) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  -- Verify the caller owns the attempt and it is still open
  if not exists (
    select 1 from public.test_attempts
    where id = p_attempt_id
      and student_id = auth.uid()
      and status = 'in_progress'
      and (expires_at is null or expires_at > now() - interval '10 seconds')
  ) then
    raise exception 'Invalid, expired, or already-submitted attempt'
      using errcode = 'insufficient_privilege';
  end if;

  insert into public.attempt_answers (
    attempt_id, 
    question_id, 
    selected_option_ids, 
    time_spent_seconds
  )
  values (
    p_attempt_id, 
    p_question_id, 
    p_selected_option_ids, 
    p_time_spent_seconds
  )
  on conflict (attempt_id, question_id)
  do update set
    selected_option_ids = excluded.selected_option_ids,
    time_spent_seconds  = attempt_answers.time_spent_seconds + excluded.time_spent_seconds,
    answered_at         = now(),
    updated_at          = now();
end;
$$;



--
-- Name: save_test_v2(uuid, jsonb, jsonb[], text); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE OR REPLACE FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_q_json jsonb;
  v_q_ids uuid[];
  v_tag_id uuid;
  v_tag_name text;
  v_opt jsonb;
  v_opt_idx int;
  v_opt_ids uuid[];
BEGIN
  -- 1. Verify ownership or new test
  IF EXISTS (SELECT 1 FROM public.tests WHERE id = p_test_id AND institute_id <> v_user_id) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  -- 2. Upsert Test (now includes shuffle_questions, shuffle_options, strict_mode)
  INSERT INTO public.tests (
    id, institute_id, title, description, instructions, 
    time_limit_seconds, available_from, available_until, status,
    shuffle_questions, shuffle_options, strict_mode
  ) VALUES (
    p_test_id,
    v_user_id,
    p_settings->>'title',
    p_settings->>'description',
    p_settings->>'instructions',
    (p_settings->>'time_limit_seconds')::int,
    (p_settings->>'available_from')::timestamptz,
    (p_settings->>'available_until')::timestamptz,
    p_status::test_status,
    COALESCE((p_settings->>'shuffle_questions')::boolean, false),
    COALESCE((p_settings->>'shuffle_options')::boolean, false),
    COALESCE((p_settings->>'strict_mode')::boolean, false)
  )
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    instructions = EXCLUDED.instructions,
    time_limit_seconds = EXCLUDED.time_limit_seconds,
    available_from = EXCLUDED.available_from,
    available_until = EXCLUDED.available_until,
    status = EXCLUDED.status,
    shuffle_questions = EXCLUDED.shuffle_questions,
    shuffle_options = EXCLUDED.shuffle_options,
    strict_mode = EXCLUDED.strict_mode;

  -- 3. Handle Questions
  v_q_ids := ARRAY(SELECT (q->>'id')::uuid FROM unnest(p_questions) AS q);
  
  DELETE FROM public.questions 
  WHERE test_id = p_test_id 
    AND id <> ALL(COALESCE(v_q_ids, ARRAY[]::uuid[]));

  FOR i IN 1..cardinality(p_questions) LOOP
    v_q_json := p_questions[i];
    
    INSERT INTO public.questions (
      id, test_id, question_text, question_type, marks, order_index, explanation
    ) VALUES (
      (v_q_json->>'id')::uuid,
      p_test_id,
      v_q_json->>'question_text',
      (v_q_json->>'question_type')::question_type,
      (v_q_json->>'marks')::numeric,
      i,
      v_q_json->>'explanation'
    )
    ON CONFLICT (id) DO UPDATE SET
      question_text = EXCLUDED.question_text,
      question_type = EXCLUDED.question_type,
      marks = EXCLUDED.marks,
      order_index = EXCLUDED.order_index,
      explanation = EXCLUDED.explanation;

    v_opt_ids := ARRAY(SELECT (o->>'id')::uuid FROM jsonb_array_elements(v_q_json->'options') AS o WHERE o ? 'id');
    
    DELETE FROM public.options 
    WHERE question_id = (v_q_json->>'id')::uuid 
      AND id <> ALL(COALESCE(v_opt_ids, ARRAY[]::uuid[]));
    
    v_opt_idx := 1;
    FOR v_opt IN SELECT jsonb_array_elements(v_q_json->'options') LOOP
      INSERT INTO public.options (id, question_id, option_text, is_correct, order_index)
      VALUES (
        COALESCE((v_opt->>'id')::uuid, gen_random_uuid()),
        (v_q_json->>'id')::uuid,
        v_opt->>'option_text',
        (v_opt->>'is_correct')::boolean,
        v_opt_idx
      )
      ON CONFLICT (id) DO UPDATE SET
        option_text = EXCLUDED.option_text,
        is_correct = EXCLUDED.is_correct,
        order_index = EXCLUDED.order_index;
      v_opt_idx := v_opt_idx + 1;
    END LOOP;

    DELETE FROM public.question_tags WHERE question_id = (v_q_json->>'id')::uuid;
    
    IF v_q_json ? 'tag_names' AND jsonb_array_length(v_q_json->'tag_names') > 0 THEN
      FOR v_tag_name IN SELECT jsonb_array_elements_text(v_q_json->'tag_names') LOOP
        INSERT INTO public.tags (name) VALUES (v_tag_name)
        ON CONFLICT (name) DO NOTHING;
        
        SELECT id INTO v_tag_id FROM public.tags WHERE name = v_tag_name;
        
        INSERT INTO public.question_tags (question_id, tag_id)
        VALUES ((v_q_json->>'id')::uuid, v_tag_id)
        ON CONFLICT DO NOTHING;
      END LOOP;
    END IF;
  END LOOP;
END;
$$;



--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$

begin

  new.updated_at = now();

  return new;

end;

$$;



--
-- Name: sync_candidate_profile(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION public.sync_candidate_profile() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

begin

  update public.profiles

  set

    display_name = nullif(new.full_name, ''),

    avatar_path   = new.profile_image_path

  where id = new.profile_id;



  return null;

end;

$$;



--
-- Name: sync_institute_profile(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION public.sync_institute_profile() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

begin

  update public.profiles

  set

    display_name = nullif(trim(new.institute_name), ''),

    avatar_path   = new.logo_path

  where id = new.profile_id;



  return null;

end;

$$;



--
-- Name: sync_user_session(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION public.sync_user_session() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$

begin

  if tg_op = 'INSERT' then

    insert into public.user_sessions (id, user_id, created_at, updated_at, not_after, ip, user_agent, tag)

    values (new.id, new.user_id, new.created_at, new.updated_at, new.not_after, new.ip, new.user_agent, new.tag)

    on conflict (id) do nothing;



  elsif tg_op = 'UPDATE' then

    update public.user_sessions set

      updated_at = new.updated_at,

      not_after  = new.not_after,

      ip         = new.ip,

      user_agent = new.user_agent,

      tag        = new.tag

    where id = new.id;



  elsif tg_op = 'DELETE' then

    delete from public.user_sessions where id = old.id;

  end if;



  return null;

end;

$$;



SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attempt_answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attempt_answers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    attempt_id uuid NOT NULL,
    question_id uuid NOT NULL,
    selected_option_ids uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    time_spent_seconds integer DEFAULT 0 NOT NULL,
    is_correct boolean,
    marks_awarded numeric(5,2),
    answered_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);



--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    username text,
    display_name text,
    avatar_path text,
    account_type text DEFAULT 'candidate'::text NOT NULL,
    account_subtype text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT profiles_account_type_check CHECK ((account_type = ANY (ARRAY['admin'::text, 'institute'::text, 'recruiter'::text, 'candidate'::text, 'tpo'::text]))),
    CONSTRAINT profiles_username_check CHECK ((username ~* '^[a-zA-Z0-9_]{3,20}$'::text))
);



--
-- Name: test_attempts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    test_id uuid NOT NULL,
    student_id uuid NOT NULL,
    status public.attempt_status DEFAULT 'in_progress'::public.attempt_status NOT NULL,
    attempt_number integer DEFAULT 1 NOT NULL,
    ip_address inet,
    user_agent text,
    tab_switch_count integer DEFAULT 0 NOT NULL,
    score numeric(7,2),
    total_marks numeric(7,2),
    percentage numeric(5,2) GENERATED ALWAYS AS (
CASE
    WHEN (total_marks > (0)::numeric) THEN round(((score / total_marks) * (100)::numeric), 2)
    ELSE NULL::numeric
END) STORED,
    passed boolean,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    submitted_at timestamp with time zone,
    time_spent_seconds integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);



--
-- Name: attempt_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.attempt_details AS
 SELECT ta.id,
    ta.test_id,
    ta.student_id,
    p.display_name AS student_name,
    p.email AS student_email,
    ta.status,
    ta.attempt_number,
    ta.score,
    ta.total_marks,
    ta.percentage,
    ta.passed,
    ta.time_spent_seconds,
    ta.tab_switch_count,
    ta.started_at,
    ta.submitted_at
   FROM (public.test_attempts ta
     JOIN public.profiles p ON ((p.id = ta.student_id)));



--
