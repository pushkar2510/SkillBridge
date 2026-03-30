-- Name: candidate_profiles; Type: TABLE; Schema: public; Owner: postgres
--

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



--
-- Name: institute_profiles; Type: TABLE; Schema: public; Owner: postgres
--

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



--
-- Name: options; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.options (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    question_id uuid NOT NULL,
    option_text text NOT NULL,
    media_url text,
    is_correct boolean DEFAULT false NOT NULL,
    order_index integer NOT NULL
);



--
-- Name: question_tags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.question_tags (
    question_id uuid NOT NULL,
    tag_id uuid NOT NULL
);



--
-- Name: questions; Type: TABLE; Schema: public; Owner: postgres
--

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



--
-- Name: tags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);



--
-- Name: tag_performance; Type: VIEW; Schema: public; Owner: postgres
--

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



--
-- Name: tests; Type: TABLE; Schema: public; Owner: postgres
--

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



--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: postgres
--

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



--
-- Name: view_question_analysis; Type: VIEW; Schema: public; Owner: postgres
--

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



--
-- Name: view_test_results_detailed; Type: VIEW; Schema: public; Owner: postgres
--

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



--
-- Name: view_test_summary; Type: VIEW; Schema: public; Owner: postgres
--

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



--
-- Name: attempt_answers attempt_answers_attempt_id_question_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attempt_answers
    ADD CONSTRAINT attempt_answers_attempt_id_question_id_key UNIQUE (attempt_id, question_id);


--
-- Name: attempt_answers attempt_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attempt_answers
    ADD CONSTRAINT attempt_answers_pkey PRIMARY KEY (id);


--
-- Name: candidate_profiles candidate_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.candidate_profiles
    ADD CONSTRAINT candidate_profiles_pkey PRIMARY KEY (profile_id);


--
-- Name: institute_profiles institute_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institute_profiles
    ADD CONSTRAINT institute_profiles_pkey PRIMARY KEY (profile_id);


--
-- Name: options options_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.options
    ADD CONSTRAINT options_pkey PRIMARY KEY (id);


--
-- Name: options options_question_id_order_index_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.options
    ADD CONSTRAINT options_question_id_order_index_key UNIQUE (question_id, order_index);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_username_key UNIQUE (username);


--
-- Name: question_tags question_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.question_tags
    ADD CONSTRAINT question_tags_pkey PRIMARY KEY (question_id, tag_id);


--
-- Name: questions questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);


--
-- Name: questions questions_test_id_order_index_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_test_id_order_index_key UNIQUE (test_id, order_index);


--
-- Name: tags tags_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_name_key UNIQUE (name);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: test_attempts test_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_pkey PRIMARY KEY (id);


--
-- Name: test_attempts test_attempts_test_id_student_id_attempt_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_test_id_student_id_attempt_number_key UNIQUE (test_id, student_id, attempt_number);


--
-- Name: tests tests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: idx_attempt_answers_attempt_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attempt_answers_attempt_id ON public.attempt_answers USING btree (attempt_id);


--
-- Name: idx_attempt_answers_question_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attempt_answers_question_id ON public.attempt_answers USING btree (question_id);


--
-- Name: idx_attempts_student_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attempts_student_id ON public.test_attempts USING btree (student_id);


--
-- Name: idx_attempts_test_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_attempts_test_id ON public.test_attempts USING btree (test_id);


--
-- Name: idx_options_question_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_options_question_id ON public.options USING btree (question_id);


--
-- Name: idx_options_question_id_order; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_options_question_id_order ON public.options USING btree (question_id, order_index);


--
-- Name: idx_question_tags_tag_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_question_tags_tag_id ON public.question_tags USING btree (tag_id);


--
-- Name: idx_questions_test_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_questions_test_id ON public.questions USING btree (test_id);


--
-- Name: idx_questions_test_id_order; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_questions_test_id_order ON public.questions USING btree (test_id, order_index);


--
-- Name: idx_test_attempts_student_test_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_test_attempts_student_test_status ON public.test_attempts USING btree (student_id, test_id, status);


--
-- Name: idx_tests_institute_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tests_institute_id ON public.tests USING btree (institute_id);


--
-- Name: idx_tests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tests_status ON public.tests USING btree (status);


--
-- Name: user_sessions_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_sessions_user_id_created_at_idx ON public.user_sessions USING btree (user_id, created_at DESC);


--
-- Name: attempt_answers trg_attempt_answers_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_attempt_answers_updated_at BEFORE UPDATE ON public.attempt_answers FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');


--
-- Name: test_attempts trg_attempts_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_attempts_updated_at BEFORE UPDATE ON public.test_attempts FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');


--
-- Name: candidate_profiles trg_candidate_profiles_sync; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_candidate_profiles_sync AFTER INSERT OR UPDATE OF first_name, middle_name, last_name, profile_image_path ON public.candidate_profiles FOR EACH ROW EXECUTE FUNCTION public.sync_candidate_profile();


--
-- Name: candidate_profiles trg_candidate_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_candidate_profiles_updated_at BEFORE UPDATE ON public.candidate_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: institute_profiles trg_institute_profiles_sync; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_institute_profiles_sync AFTER INSERT OR UPDATE OF institute_name, logo_path ON public.institute_profiles FOR EACH ROW EXECUTE FUNCTION public.sync_institute_profile();


--
-- Name: institute_profiles trg_institute_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_institute_profiles_updated_at BEFORE UPDATE ON public.institute_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: profiles trg_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: questions trg_questions_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_questions_updated_at BEFORE UPDATE ON public.questions FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');


--
-- Name: tests trg_tests_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER trg_tests_updated_at BEFORE UPDATE ON public.tests FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');


--
-- Name: attempt_answers attempt_answers_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attempt_answers
    ADD CONSTRAINT attempt_answers_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.test_attempts(id) ON DELETE CASCADE;


--
-- Name: attempt_answers attempt_answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attempt_answers
    ADD CONSTRAINT attempt_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;


--
-- Name: candidate_profiles candidate_profiles_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.candidate_profiles
    ADD CONSTRAINT candidate_profiles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: institute_profiles institute_profiles_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institute_profiles
    ADD CONSTRAINT institute_profiles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: options options_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.options
    ADD CONSTRAINT options_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: question_tags question_tags_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.question_tags
    ADD CONSTRAINT question_tags_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;


--
-- Name: question_tags question_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.question_tags
    ADD CONSTRAINT question_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: questions questions_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;


--
-- Name: test_attempts test_attempts_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: test_attempts test_attempts_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;


--
-- Name: tests tests_institute_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_institute_id_fkey FOREIGN KEY (institute_id) REFERENCES public.institute_profiles(profile_id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: attempt_answers Attempt answers are viewable by student and institute; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Attempt answers are viewable by student and institute" ON public.attempt_answers FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.test_attempts
  WHERE ((test_attempts.id = attempt_answers.attempt_id) AND ((test_attempts.student_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
           FROM public.tests
          WHERE ((tests.id = test_attempts.test_id) AND (tests.institute_id = ( SELECT auth.uid() AS uid))))))))));


--
-- Name: tags Authenticated users can create tags; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Authenticated users can create tags" ON public.tags FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: candidate_profiles Candidate profiles are viewable by authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Candidate profiles are viewable by authenticated users" ON public.candidate_profiles FOR SELECT TO authenticated USING (true);


--
-- Name: institute_profiles Institute profiles are viewable by authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute profiles are viewable by authenticated users" ON public.institute_profiles FOR SELECT TO authenticated USING (true);


--
-- Name: tests Institutes can delete their own tests; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can delete their own tests" ON public.tests FOR DELETE TO authenticated USING ((institute_id = ( SELECT auth.uid() AS uid)));


--
-- Name: tests Institutes can insert their own tests; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can insert their own tests" ON public.tests FOR INSERT TO authenticated WITH CHECK ((institute_id = ( SELECT auth.uid() AS uid)));


--
-- Name: options Institutes can modify options for their tests_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify options for their tests_delete" ON public.options FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = options.question_id) AND (t.institute_id = auth.uid())))));


--
-- Name: options Institutes can modify options for their tests_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify options for their tests_insert" ON public.options FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = options.question_id) AND (t.institute_id = auth.uid())))));


--
-- Name: options Institutes can modify options for their tests_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify options for their tests_update" ON public.options FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = options.question_id) AND (t.institute_id = auth.uid())))));


--
-- Name: question_tags Institutes can modify question tags for their tests_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify question tags for their tests_delete" ON public.question_tags FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = question_tags.question_id) AND (t.institute_id = auth.uid())))));


--
-- Name: question_tags Institutes can modify question tags for their tests_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify question tags for their tests_insert" ON public.question_tags FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = question_tags.question_id) AND (t.institute_id = auth.uid())))));


--
-- Name: question_tags Institutes can modify question tags for their tests_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify question tags for their tests_update" ON public.question_tags FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.questions q
     JOIN public.tests t ON ((q.test_id = t.id)))
  WHERE ((q.id = question_tags.question_id) AND (t.institute_id = auth.uid())))));


--
-- Name: questions Institutes can modify questions for their tests_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify questions for their tests_delete" ON public.questions FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.tests
  WHERE ((tests.id = questions.test_id) AND (tests.institute_id = auth.uid())))));


--
-- Name: questions Institutes can modify questions for their tests_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify questions for their tests_insert" ON public.questions FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.tests
  WHERE ((tests.id = questions.test_id) AND (tests.institute_id = auth.uid())))));


--
-- Name: questions Institutes can modify questions for their tests_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can modify questions for their tests_update" ON public.questions FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.tests
  WHERE ((tests.id = questions.test_id) AND (tests.institute_id = auth.uid())))));


--
-- Name: tests Institutes can update their own tests; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can update their own tests" ON public.tests FOR UPDATE TO authenticated USING ((institute_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((institute_id = ( SELECT auth.uid() AS uid)));


--
