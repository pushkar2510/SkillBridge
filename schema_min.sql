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
CREATE TYPE public.attempt_status AS ENUM (
    'in_progress',
    'submitted',
    'abandoned',
    'auto_submitted'
);
CREATE TYPE public.question_type AS ENUM (
    'single_correct',
    'multiple_correct',
    'true_false'
);
CREATE TYPE public.test_status AS ENUM (
    'draft',
    'published',
    'archived'
);
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
    SELECT * INTO v_profile 
    FROM public.candidate_profiles 
    WHERE profile_id = p_profile_id;
    IF v_profile.profile_id IS NOT NULL AND v_profile.institute_id IS NOT NULL THEN
        SELECT count(*) INTO v_total_tests
        FROM public.tests
        WHERE status = 'published' AND institute_id = v_profile.institute_id;
        SELECT count(*) INTO v_live_tests
        FROM public.tests
        WHERE status = 'published' 
          AND institute_id = v_profile.institute_id
          AND (available_from IS NULL OR available_from <= v_now)
          AND (available_until IS NULL OR available_until >= v_now);
        SELECT count(*) INTO v_upcoming_tests
        FROM public.tests
        WHERE status = 'published' 
          AND institute_id = v_profile.institute_id
          AND available_from > v_now;
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
    SELECT * INTO v_profile 
    FROM public.institute_profiles 
    WHERE profile_id = p_profile_id;
    SELECT count(*) INTO v_total_tests
    FROM public.tests
    WHERE institute_id = p_profile_id;
    SELECT count(*) INTO v_live_tests
    FROM public.tests
    WHERE institute_id = p_profile_id 
      AND status = 'published' 
      AND (available_from IS NULL OR available_from <= v_now)
      AND (available_until IS NULL OR available_until >= v_now);
    SELECT count(*) INTO v_upcoming_tests
    FROM public.tests
    WHERE institute_id = p_profile_id 
      AND status = 'published'
      AND available_from > v_now;
    SELECT count(*) INTO v_past_tests
    FROM public.tests
    WHERE institute_id = p_profile_id 
      AND status = 'published'
      AND available_until < v_now;
    SELECT count(*) INTO v_draft_tests
    FROM public.tests
    WHERE institute_id = p_profile_id 
      AND status = 'draft';
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
    UPDATE public.test_attempts
    SET time_spent_seconds = p_final_time_spent
    WHERE id = p_attempt_id
       AND student_id = auth.uid()
       AND status IN ('in_progress', 'auto_submitted')
    RETURNING test_id INTO v_test_id;
    IF v_test_id IS NULL THEN
        RETURN jsonb_build_object('error', 'Attempt not found or already submitted');
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
    RETURN jsonb_build_object(
        'status', 'submitted',
        'test_id', v_test_id,
        'score', v_scored,
        'total_marks', v_total
    );
END;
$$;
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
    SELECT institute_id, profile_complete, profile_updated 
    INTO v_profile FROM public.candidate_profiles WHERE profile_id = v_user_id;
    IF v_profile IS NULL OR NOT COALESCE(v_profile.profile_complete, FALSE) OR NOT COALESCE(v_profile.profile_updated, FALSE) THEN
        RETURN jsonb_build_object('error', 'Profile incomplete');
    END IF;
    SELECT id, status, institute_id, time_limit_seconds, max_attempts, title
    INTO v_test FROM public.tests WHERE id = p_test_id;
    IF v_test IS NULL OR v_test.status != 'published' OR v_test.institute_id != v_profile.institute_id THEN
        RETURN jsonb_build_object('error', 'Test not available or invalid institute');
    END IF;
    SELECT id, started_at, expires_at, tab_switch_count 
    INTO v_existing_attempt
    FROM public.test_attempts 
    WHERE test_id = p_test_id AND student_id = v_user_id AND status = 'in_progress'
    ORDER BY created_at DESC LIMIT 1;
    IF v_existing_attempt IS NOT NULL THEN
        IF v_existing_attempt.expires_at IS NOT NULL AND v_existing_attempt.expires_at < NOW() THEN
            PERFORM public.grade_attempt(v_existing_attempt.id);
            RETURN jsonb_build_object('status', 'expired', 'test_id', p_test_id);
        END IF;
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
    SELECT count(*) INTO v_completed_count 
    FROM public.test_attempts 
    WHERE test_id = p_test_id AND student_id = v_user_id 
    AND status IN ('submitted', 'auto_submitted');
    IF v_completed_count >= v_test.max_attempts THEN
        RETURN jsonb_build_object('error', 'Max attempts reached (' || v_completed_count || '/' || v_test.max_attempts || ')');
    END IF;
    RETURN jsonb_build_object(
        'status', 'ready',
        'completed_count', v_completed_count,
        'max_attempts', v_test.max_attempts
    );
END;
$$;
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
CREATE OR REPLACE FUNCTION public.save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer DEFAULT 0) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
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
  IF EXISTS (SELECT 1 FROM public.tests WHERE id = p_test_id AND institute_id <> v_user_id) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
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
CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;
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
CREATE TABLE public.candidate_profiles (
    profile_id uuid NOT NULL,
    first_name text,
    middle_name text,
    last_name text,
    full_name text GENERATED ALWAYS AS (TRIM(BOTH FROM ((COALESCE((NULLIF(TRIM(BOTH FROM first_name), ''::text) || ' '::text), ''::text) || COALESCE((NULLIF(TRIM(BOTH FROM middle_name), ''::text) || ' '::text), ''::text)) || COALESCE(NULLIF(TRIM(BOTH FROM last_name), ''::text), ''::text)))) STORED,
    gender character(1),
    phone_number text,
    date_of_birth date,
    aadhaar_number text,
    current_address text,
    permanent_address text,
    institute_id uuid,
    institute_verified boolean,
    university_prn text,
    course_name text,
    passout_year smallint,
    ssc_percentage numeric(5,2),
    ssc_pass_year smallint,
    hsc_percentage numeric(5,2),
    hsc_pass_year smallint,
    diploma_percentage numeric(5,2),
    diploma_pass_year smallint,
    sgpa_sem1 numeric(4,2),
    sgpa_sem2 numeric(4,2),
    sgpa_sem3 numeric(4,2),
    sgpa_sem4 numeric(4,2),
    sgpa_sem5 numeric(4,2),
    sgpa_sem6 numeric(4,2),
    sgpa_sem7 numeric(4,2),
    sgpa_sem8 numeric(4,2),
    sgpa_sem9 numeric(4,2),
    sgpa_sem10 numeric(4,2),
    cgpa numeric(4,2) GENERATED ALWAYS AS (round(((((((((((COALESCE(sgpa_sem1, (0)::numeric) + COALESCE(sgpa_sem2, (0)::numeric)) + COALESCE(sgpa_sem3, (0)::numeric)) + COALESCE(sgpa_sem4, (0)::numeric)) + COALESCE(sgpa_sem5, (0)::numeric)) + COALESCE(sgpa_sem6, (0)::numeric)) + COALESCE(sgpa_sem7, (0)::numeric)) + COALESCE(sgpa_sem8, (0)::numeric)) + COALESCE(sgpa_sem9, (0)::numeric)) + COALESCE(sgpa_sem10, (0)::numeric)) / (NULLIF((((((((((((sgpa_sem1 IS NOT NULL))::integer + ((sgpa_sem2 IS NOT NULL))::integer) + ((sgpa_sem3 IS NOT NULL))::integer) + ((sgpa_sem4 IS NOT NULL))::integer) + ((sgpa_sem5 IS NOT NULL))::integer) + ((sgpa_sem6 IS NOT NULL))::integer) + ((sgpa_sem7 IS NOT NULL))::integer) + ((sgpa_sem8 IS NOT NULL))::integer) + ((sgpa_sem9 IS NOT NULL))::integer) + ((sgpa_sem10 IS NOT NULL))::integer), 0))::numeric), 2)) STORED,
    is_hsc boolean,
    is_diploma boolean,
    profile_updated boolean DEFAULT false NOT NULL,
    profile_image_path text,
    skills text[],
    linkedin_url text,
    github_url text,
    portfolio_links text[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    profile_complete boolean GENERATED ALWAYS AS (((first_name IS NOT NULL) AND (TRIM(BOTH FROM first_name) <> ''::text) AND (middle_name IS NOT NULL) AND (TRIM(BOTH FROM middle_name) <> ''::text) AND (last_name IS NOT NULL) AND (TRIM(BOTH FROM last_name) <> ''::text) AND (phone_number IS NOT NULL) AND (date_of_birth IS NOT NULL) AND (gender IS NOT NULL) AND (institute_id IS NOT NULL) AND (course_name IS NOT NULL) AND (passout_year IS NOT NULL) AND (ssc_percentage IS NOT NULL))) STORED,
    CONSTRAINT candidate_profiles_aadhaar_number_check CHECK ((aadhaar_number ~ '^[0-9]{12}$'::text)),
    CONSTRAINT candidate_profiles_cgpa_check CHECK ((cgpa <= (10)::numeric)),
    CONSTRAINT candidate_profiles_date_of_birth_check CHECK ((date_of_birth <= CURRENT_DATE)),
    CONSTRAINT candidate_profiles_diploma_percentage_check CHECK ((diploma_percentage <= (100)::numeric)),
    CONSTRAINT candidate_profiles_gender_check CHECK ((gender = ANY (ARRAY['M'::bpchar, 'F'::bpchar, 'O'::bpchar]))),
    CONSTRAINT candidate_profiles_hsc_percentage_check CHECK ((hsc_percentage <= (100)::numeric)),
    CONSTRAINT candidate_profiles_phone_number_check CHECK ((phone_number ~ '^[0-9]{10}$'::text)),
    CONSTRAINT candidate_profiles_sgpa_sem10_check CHECK ((sgpa_sem10 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem1_check CHECK ((sgpa_sem1 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem2_check CHECK ((sgpa_sem2 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem3_check CHECK ((sgpa_sem3 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem4_check CHECK ((sgpa_sem4 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem5_check CHECK ((sgpa_sem5 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem6_check CHECK ((sgpa_sem6 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem7_check CHECK ((sgpa_sem7 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem8_check CHECK ((sgpa_sem8 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_sgpa_sem9_check CHECK ((sgpa_sem9 <= (10)::numeric)),
    CONSTRAINT candidate_profiles_ssc_percentage_check CHECK ((ssc_percentage <= (100)::numeric))
);
CREATE TABLE public.institute_profiles (
    profile_id uuid NOT NULL,
    institute_name text NOT NULL,
    institute_code text,
    established_year smallint,
    affiliation text,
    address text,
    city text,
    state text,
    pincode text,
    country text DEFAULT 'India'::text,
    phone_number text,
    email text,
    website_url text,
    principal_name text,
    principal_email text,
    principal_phone text,
    courses text[],
    social_links text[],
    logo_path text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    profile_updated boolean DEFAULT false NOT NULL,
    profile_complete boolean GENERATED ALWAYS AS (((institute_name IS NOT NULL) AND (TRIM(BOTH FROM institute_name) <> ''::text) AND ((address IS NOT NULL) AND (TRIM(BOTH FROM address) <> ''::text)) AND ((city IS NOT NULL) AND (TRIM(BOTH FROM city) <> ''::text)) AND ((state IS NOT NULL) AND (TRIM(BOTH FROM state) <> ''::text)) AND ((phone_number IS NOT NULL) AND (TRIM(BOTH FROM phone_number) <> ''::text)) AND ((email IS NOT NULL) AND (TRIM(BOTH FROM email) <> ''::text)))) STORED
);
CREATE TABLE public.options (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    question_id uuid NOT NULL,
    option_text text NOT NULL,
    media_url text,
    is_correct boolean DEFAULT false NOT NULL,
    order_index integer NOT NULL
);
CREATE TABLE public.question_tags (
    question_id uuid NOT NULL,
    tag_id uuid NOT NULL
);
CREATE TABLE public.questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    test_id uuid NOT NULL,
    question_text text NOT NULL,
    question_type public.question_type NOT NULL,
    media_url text,
    order_index integer NOT NULL,
    marks numeric(5,2) DEFAULT 1 NOT NULL,
    negative_marks numeric(5,2) DEFAULT 0 NOT NULL,
    explanation text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE OR REPLACE VIEW public.tag_performance AS
 SELECT ta.student_id,
    ta.test_id,
    tg.id AS tag_id,
    tg.name AS tag_name,
    count(aa.id) AS total_questions,
    sum(
        CASE
            WHEN aa.is_correct THEN 1
            ELSE 0
        END) AS correct_count,
    round((((sum(
        CASE
            WHEN aa.is_correct THEN 1
            ELSE 0
        END))::numeric / (NULLIF(count(aa.id), 0))::numeric) * (100)::numeric), 1) AS accuracy_pct
   FROM (((public.attempt_answers aa
     JOIN public.test_attempts ta ON ((ta.id = aa.attempt_id)))
     JOIN public.question_tags qt ON ((qt.question_id = aa.question_id)))
     JOIN public.tags tg ON ((tg.id = qt.tag_id)))
  WHERE (ta.status = ANY (ARRAY['submitted'::public.attempt_status, 'auto_submitted'::public.attempt_status]))
  GROUP BY ta.student_id, ta.test_id, tg.id, tg.name;
CREATE TABLE public.tests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    instructions text,
    time_limit_seconds integer,
    pass_percentage numeric(5,2),
    shuffle_questions boolean DEFAULT false NOT NULL,
    shuffle_options boolean DEFAULT false NOT NULL,
    strict_mode boolean DEFAULT false NOT NULL,
    max_attempts integer DEFAULT 1 NOT NULL,
    available_from timestamp with time zone,
    available_until timestamp with time zone,
    results_available boolean DEFAULT false NOT NULL,
    status public.test_status DEFAULT 'draft'::public.test_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.user_sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    not_after timestamp with time zone,
    ip inet,
    user_agent text,
    tag text
);
CREATE OR REPLACE VIEW public.view_question_analysis AS
 SELECT q.id AS question_id,
    q.test_id,
    q.question_text,
    q.marks,
    count(aa.id) AS total_answers,
    sum(
        CASE
            WHEN aa.is_correct THEN 1
            ELSE 0
        END) AS correct_answers,
    round((((sum(
        CASE
            WHEN aa.is_correct THEN 1
            ELSE 0
        END))::numeric / (NULLIF(count(aa.id), 0))::numeric) * (100)::numeric), 1) AS success_rate_pct,
    round(avg(aa.time_spent_seconds), 1) AS avg_time_spent
   FROM (public.questions q
     LEFT JOIN public.attempt_answers aa ON ((aa.question_id = q.id)))
  GROUP BY q.id, q.test_id, q.question_text, q.marks;
CREATE OR REPLACE VIEW public.view_test_results_detailed AS
 SELECT ta.id AS attempt_id,
    ta.test_id,
    ta.student_id,
    p.display_name AS student_name,
    p.email AS student_email,
    cp.course_name AS branch,
    cp.passout_year,
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
   FROM ((public.test_attempts ta
     JOIN public.profiles p ON ((p.id = ta.student_id)))
     LEFT JOIN public.candidate_profiles cp ON ((cp.profile_id = ta.student_id)));
CREATE OR REPLACE VIEW public.view_test_summary AS
 SELECT t.id,
    t.title,
    t.description,
    t.institute_id,
    ip.institute_name,
    t.status,
    t.available_from,
    t.available_until,
    t.time_limit_seconds,
    t.results_available,
    ( SELECT count(*) AS count
           FROM public.questions q
          WHERE (q.test_id = t.id)) AS question_count,
    ( SELECT COALESCE(sum(q.marks), (0)::numeric) AS "coalesce"
           FROM public.questions q
          WHERE (q.test_id = t.id)) AS total_marks,
    ( SELECT count(*) AS count
           FROM public.test_attempts ta
          WHERE (ta.test_id = t.id)) AS total_attempts,
    ( SELECT count(*) AS count
           FROM public.test_attempts ta
          WHERE ((ta.test_id = t.id) AND (ta.status = 'submitted'::public.attempt_status))) AS submitted_attempts,
    ( SELECT round(avg(ta.percentage), 1) AS round
           FROM public.test_attempts ta
          WHERE ((ta.test_id = t.id) AND (ta.status = 'submitted'::public.attempt_status))) AS avg_score_pct
   FROM (public.tests t
     LEFT JOIN public.institute_profiles ip ON ((t.institute_id = ip.profile_id)));
ALTER TABLE ONLY public.attempt_answers
    ADD CONSTRAINT attempt_answers_attempt_id_question_id_key UNIQUE (attempt_id, question_id);
ALTER TABLE ONLY public.attempt_answers
    ADD CONSTRAINT attempt_answers_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.candidate_profiles
    ADD CONSTRAINT candidate_profiles_pkey PRIMARY KEY (profile_id);
ALTER TABLE ONLY public.institute_profiles
    ADD CONSTRAINT institute_profiles_pkey PRIMARY KEY (profile_id);
ALTER TABLE ONLY public.options
    ADD CONSTRAINT options_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.options
    ADD CONSTRAINT options_question_id_order_index_key UNIQUE (question_id, order_index);
ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_username_key UNIQUE (username);
ALTER TABLE ONLY public.question_tags
    ADD CONSTRAINT question_tags_pkey PRIMARY KEY (question_id, tag_id);
ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_test_id_order_index_key UNIQUE (test_id, order_index);
ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_name_key UNIQUE (name);
ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_test_id_student_id_attempt_number_key UNIQUE (test_id, student_id, attempt_number);
ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);
CREATE INDEX idx_attempt_answers_attempt_id ON public.attempt_answers USING btree (attempt_id);
CREATE INDEX idx_attempt_answers_question_id ON public.attempt_answers USING btree (question_id);
CREATE INDEX idx_attempts_student_id ON public.test_attempts USING btree (student_id);
CREATE INDEX idx_attempts_test_id ON public.test_attempts USING btree (test_id);
CREATE INDEX idx_options_question_id ON public.options USING btree (question_id);
CREATE INDEX idx_options_question_id_order ON public.options USING btree (question_id, order_index);
CREATE INDEX idx_question_tags_tag_id ON public.question_tags USING btree (tag_id);
CREATE INDEX idx_questions_test_id ON public.questions USING btree (test_id);
CREATE INDEX idx_questions_test_id_order ON public.questions USING btree (test_id, order_index);
CREATE INDEX idx_test_attempts_student_test_status ON public.test_attempts USING btree (student_id, test_id, status);
CREATE INDEX idx_tests_institute_id ON public.tests USING btree (institute_id);
CREATE INDEX idx_tests_status ON public.tests USING btree (status);
CREATE INDEX user_sessions_user_id_created_at_idx ON public.user_sessions USING btree (user_id, created_at DESC);
CREATE OR REPLACE TRIGGER trg_attempt_answers_updated_at BEFORE UPDATE ON public.attempt_answers FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');
CREATE OR REPLACE TRIGGER trg_attempts_updated_at BEFORE UPDATE ON public.test_attempts FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');
CREATE OR REPLACE TRIGGER trg_candidate_profiles_sync AFTER INSERT OR UPDATE OF first_name, middle_name, last_name, profile_image_path ON public.candidate_profiles FOR EACH ROW EXECUTE FUNCTION public.sync_candidate_profile();
CREATE OR REPLACE TRIGGER trg_candidate_profiles_updated_at BEFORE UPDATE ON public.candidate_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE OR REPLACE TRIGGER trg_institute_profiles_sync AFTER INSERT OR UPDATE OF institute_name, logo_path ON public.institute_profiles FOR EACH ROW EXECUTE FUNCTION public.sync_institute_profile();
CREATE OR REPLACE TRIGGER trg_institute_profiles_updated_at BEFORE UPDATE ON public.institute_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE OR REPLACE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE OR REPLACE TRIGGER trg_questions_updated_at BEFORE UPDATE ON public.questions FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');
CREATE OR REPLACE TRIGGER trg_tests_updated_at BEFORE UPDATE ON public.tests FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');
ALTER TABLE ONLY public.attempt_answers
    ADD CONSTRAINT attempt_answers_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.test_attempts(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.attempt_answers
    ADD CONSTRAINT attempt_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.candidate_profiles
    ADD CONSTRAINT candidate_profiles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.institute_profiles
    ADD CONSTRAINT institute_profiles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.options
    ADD CONSTRAINT options_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.question_tags
    ADD CONSTRAINT question_tags_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.question_tags
    ADD CONSTRAINT question_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_institute_id_fkey FOREIGN KEY (institute_id) REFERENCES public.institute_profiles(profile_id) ON DELETE CASCADE;
ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
CREATE POLICY "Attempt answers are viewable by student and institute" ON public.attempt_answers FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.test_attempts
  WHERE ((test_attempts.id = attempt_answers.attempt_id) AND ((test_attempts.student_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
           FROM public.tests
          WHERE ((tests.id = test_attempts.test_id) AND (tests.institute_id = ( SELECT auth.uid() AS uid))))))))));
CREATE POLICY "Authenticated users can create tags" ON public.tags FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Candidate profiles are viewable by authenticated users" ON public.candidate_profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Institute profiles are viewable by authenticated users" ON public.institute_profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Institutes can delete their own tests" ON public.tests FOR DELETE TO authenticated USING ((institute_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Institutes can insert their own tests" ON public.tests FOR INSERT TO authenticated WITH CHECK ((institute_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Institutes can modify options for their tests_delete" ON public.options FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = options.question_id) AND (t.institute_id = auth.uid())))));
CREATE POLICY "Institutes can modify options for their tests_insert" ON public.options FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = options.question_id) AND (t.institute_id = auth.uid())))));
CREATE POLICY "Institutes can modify options for their tests_update" ON public.options FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = options.question_id) AND (t.institute_id = auth.uid())))));
CREATE POLICY "Institutes can modify question tags for their tests_delete" ON public.question_tags FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = question_tags.question_id) AND (t.institute_id = auth.uid())))));
CREATE POLICY "Institutes can modify question tags for their tests_insert" ON public.question_tags FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = question_tags.question_id) AND (t.institute_id = auth.uid())))));
CREATE POLICY "Institutes can modify question tags for their tests_update" ON public.question_tags FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = question_tags.question_id) AND (t.institute_id = auth.uid())))));
CREATE POLICY "Institutes can modify questions for their tests_delete" ON public.questions FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.tests
  WHERE ((tests.id = questions.test_id) AND (tests.institute_id = auth.uid())))));
CREATE POLICY "Institutes can modify questions for their tests_insert" ON public.questions FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.tests
  WHERE ((tests.id = questions.test_id) AND (tests.institute_id = auth.uid())))));
CREATE POLICY "Institutes can modify questions for their tests_update" ON public.questions FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.tests
  WHERE ((tests.id = questions.test_id) AND (tests.institute_id = auth.uid())))));
CREATE POLICY "Institutes can update their own tests" ON public.tests FOR UPDATE TO authenticated USING ((institute_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((institute_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Options are viewable by authenticated users" ON public.options FOR SELECT TO authenticated USING (true);
CREATE POLICY "Profiles are viewable by all authenticated users" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Question tags are viewable by authenticated users" ON public.question_tags FOR SELECT TO authenticated USING (true);
CREATE POLICY "Questions are viewable by authenticated users" ON public.questions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Students can insert their own attempt answers" ON public.attempt_answers FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.test_attempts
  WHERE ((test_attempts.id = attempt_answers.attempt_id) AND (test_attempts.student_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "Students can insert their own test attempts" ON public.test_attempts FOR INSERT TO authenticated WITH CHECK ((student_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Students can update their own attempt answers" ON public.attempt_answers FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.test_attempts
  WHERE ((test_attempts.id = attempt_answers.attempt_id) AND (test_attempts.student_id = ( SELECT auth.uid() AS uid)))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.test_attempts
  WHERE ((test_attempts.id = attempt_answers.attempt_id) AND (test_attempts.student_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "Students can update their own test attempts" ON public.test_attempts FOR UPDATE TO authenticated USING ((student_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((student_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Tags are viewable by authenticated users" ON public.tags FOR SELECT TO authenticated USING (true);
CREATE POLICY "Test attempts are viewable by student and institute" ON public.test_attempts FOR SELECT TO authenticated USING (((student_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM public.tests
  WHERE ((tests.id = test_attempts.test_id) AND (tests.institute_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "Tests are viewable by authenticated users" ON public.tests FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can delete their own candidate profile" ON public.candidate_profiles FOR DELETE TO authenticated USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can delete their own institute profile" ON public.institute_profiles FOR DELETE TO authenticated USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can delete their own profile" ON public.profiles FOR DELETE TO authenticated USING ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can delete their own sessions" ON public.user_sessions FOR DELETE USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "Users can insert their own candidate profile" ON public.candidate_profiles FOR INSERT TO authenticated WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can insert their own institute profile" ON public.institute_profiles FOR INSERT TO authenticated WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can update their own candidate profile" ON public.candidate_profiles FOR UPDATE TO authenticated USING ((profile_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can update their own institute profile" ON public.institute_profiles FOR UPDATE TO authenticated USING ((profile_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "Users can view their own sessions" ON public.user_sessions FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));
ALTER TABLE public.attempt_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidate_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.institute_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;
REVOKE ALL ON FUNCTION public.check_username_available(p_username text, p_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.check_username_available(p_username text, p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.check_username_available(p_username text, p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.check_username_available(p_username text, p_user_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.get_candidate_home_stats(p_profile_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.get_candidate_home_stats(p_profile_id uuid) TO anon;
GRANT ALL ON FUNCTION public.get_candidate_home_stats(p_profile_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_candidate_home_stats(p_profile_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.get_institute_home_stats(p_profile_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.get_institute_home_stats(p_profile_id uuid) TO anon;
GRANT ALL ON FUNCTION public.get_institute_home_stats(p_profile_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_institute_home_stats(p_profile_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.grade_attempt(p_attempt_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.grade_attempt(p_attempt_id uuid) TO anon;
GRANT ALL ON FUNCTION public.grade_attempt(p_attempt_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.grade_attempt(p_attempt_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) TO postgres;
GRANT ALL ON FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) TO anon;
GRANT ALL ON FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) TO authenticated;
GRANT ALL ON FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) TO service_role;
GRANT ALL ON FUNCTION public.handle_new_user() TO anon;
GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;
GRANT ALL ON FUNCTION public.handle_session_sync() TO postgres;
GRANT ALL ON FUNCTION public.handle_session_sync() TO anon;
GRANT ALL ON FUNCTION public.handle_session_sync() TO authenticated;
GRANT ALL ON FUNCTION public.handle_session_sync() TO service_role;
GRANT ALL ON FUNCTION public.init_test_attempt(p_test_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.init_test_attempt(p_test_id uuid) TO anon;
GRANT ALL ON FUNCTION public.init_test_attempt(p_test_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.init_test_attempt(p_test_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.revoke_session(p_session_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.revoke_session(p_session_id uuid) TO anon;
GRANT ALL ON FUNCTION public.revoke_session(p_session_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.revoke_session(p_session_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) TO postgres;
GRANT ALL ON FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) TO anon;
GRANT ALL ON FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) TO authenticated;
GRANT ALL ON FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) TO service_role;
GRANT ALL ON FUNCTION public.save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer) TO anon;
GRANT ALL ON FUNCTION public.save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer) TO authenticated;
GRANT ALL ON FUNCTION public.save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer) TO service_role;
GRANT ALL ON FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) TO postgres;
GRANT ALL ON FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) TO anon;
GRANT ALL ON FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) TO authenticated;
GRANT ALL ON FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) TO service_role;
GRANT ALL ON FUNCTION public.set_updated_at() TO anon;
GRANT ALL ON FUNCTION public.set_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.set_updated_at() TO service_role;
GRANT ALL ON FUNCTION public.sync_candidate_profile() TO anon;
GRANT ALL ON FUNCTION public.sync_candidate_profile() TO authenticated;
GRANT ALL ON FUNCTION public.sync_candidate_profile() TO service_role;
GRANT ALL ON FUNCTION public.sync_institute_profile() TO anon;
GRANT ALL ON FUNCTION public.sync_institute_profile() TO authenticated;
GRANT ALL ON FUNCTION public.sync_institute_profile() TO service_role;
GRANT ALL ON FUNCTION public.sync_user_session() TO anon;
GRANT ALL ON FUNCTION public.sync_user_session() TO authenticated;
GRANT ALL ON FUNCTION public.sync_user_session() TO service_role;
GRANT ALL ON TABLE public.attempt_answers TO anon;
GRANT ALL ON TABLE public.attempt_answers TO authenticated;
GRANT ALL ON TABLE public.attempt_answers TO service_role;
GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;
GRANT ALL ON TABLE public.test_attempts TO anon;
GRANT ALL ON TABLE public.test_attempts TO authenticated;
GRANT ALL ON TABLE public.test_attempts TO service_role;
GRANT ALL ON TABLE public.attempt_details TO anon;
GRANT ALL ON TABLE public.attempt_details TO authenticated;
GRANT ALL ON TABLE public.attempt_details TO service_role;
GRANT ALL ON TABLE public.candidate_profiles TO anon;
GRANT ALL ON TABLE public.candidate_profiles TO authenticated;
GRANT ALL ON TABLE public.candidate_profiles TO service_role;
GRANT ALL ON TABLE public.institute_profiles TO anon;
GRANT ALL ON TABLE public.institute_profiles TO authenticated;
GRANT ALL ON TABLE public.institute_profiles TO service_role;
GRANT ALL ON TABLE public.options TO anon;
GRANT ALL ON TABLE public.options TO authenticated;
GRANT ALL ON TABLE public.options TO service_role;
GRANT ALL ON TABLE public.question_tags TO anon;
GRANT ALL ON TABLE public.question_tags TO authenticated;
GRANT ALL ON TABLE public.question_tags TO service_role;
GRANT ALL ON TABLE public.questions TO anon;
GRANT ALL ON TABLE public.questions TO authenticated;
GRANT ALL ON TABLE public.questions TO service_role;
GRANT ALL ON TABLE public.tags TO anon;
GRANT ALL ON TABLE public.tags TO authenticated;
GRANT ALL ON TABLE public.tags TO service_role;
GRANT ALL ON TABLE public.tag_performance TO anon;
GRANT ALL ON TABLE public.tag_performance TO authenticated;
GRANT ALL ON TABLE public.tag_performance TO service_role;
GRANT ALL ON TABLE public.tests TO anon;
GRANT ALL ON TABLE public.tests TO authenticated;
GRANT ALL ON TABLE public.tests TO service_role;
GRANT ALL ON TABLE public.user_sessions TO anon;
GRANT ALL ON TABLE public.user_sessions TO authenticated;
GRANT ALL ON TABLE public.user_sessions TO service_role;
GRANT ALL ON TABLE public.view_question_analysis TO anon;
GRANT ALL ON TABLE public.view_question_analysis TO authenticated;
GRANT ALL ON TABLE public.view_question_analysis TO service_role;
GRANT ALL ON TABLE public.view_test_results_detailed TO anon;
GRANT ALL ON TABLE public.view_test_results_detailed TO authenticated;
GRANT ALL ON TABLE public.view_test_results_detailed TO service_role;
GRANT ALL ON TABLE public.view_test_summary TO anon;
GRANT ALL ON TABLE public.view_test_summary TO authenticated;
GRANT ALL ON TABLE public.view_test_summary TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO service_role;