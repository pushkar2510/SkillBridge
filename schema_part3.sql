-- Name: options Options are viewable by authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Options are viewable by authenticated users" ON public.options FOR SELECT TO authenticated USING (true);


--
-- Name: profiles Profiles are viewable by all authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Profiles are viewable by all authenticated users" ON public.profiles FOR SELECT TO authenticated USING (true);


--
-- Name: question_tags Question tags are viewable by authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Question tags are viewable by authenticated users" ON public.question_tags FOR SELECT TO authenticated USING (true);


--
-- Name: questions Questions are viewable by authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Questions are viewable by authenticated users" ON public.questions FOR SELECT TO authenticated USING (true);


--
-- Name: attempt_answers Students can insert their own attempt answers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can insert their own attempt answers" ON public.attempt_answers FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.test_attempts
  WHERE ((test_attempts.id = attempt_answers.attempt_id) AND (test_attempts.student_id = ( SELECT auth.uid() AS uid))))));


--
-- Name: test_attempts Students can insert their own test attempts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can insert their own test attempts" ON public.test_attempts FOR INSERT TO authenticated WITH CHECK ((student_id = ( SELECT auth.uid() AS uid)));


--
-- Name: attempt_answers Students can update their own attempt answers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can update their own attempt answers" ON public.attempt_answers FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.test_attempts
  WHERE ((test_attempts.id = attempt_answers.attempt_id) AND (test_attempts.student_id = ( SELECT auth.uid() AS uid)))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.test_attempts
  WHERE ((test_attempts.id = attempt_answers.attempt_id) AND (test_attempts.student_id = ( SELECT auth.uid() AS uid))))));


--
-- Name: test_attempts Students can update their own test attempts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can update their own test attempts" ON public.test_attempts FOR UPDATE TO authenticated USING ((student_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((student_id = ( SELECT auth.uid() AS uid)));


--
-- Name: tags Tags are viewable by authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Tags are viewable by authenticated users" ON public.tags FOR SELECT TO authenticated USING (true);


--
-- Name: test_attempts Test attempts are viewable by student and institute; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Test attempts are viewable by student and institute" ON public.test_attempts FOR SELECT TO authenticated USING (((student_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM public.tests
  WHERE ((tests.id = test_attempts.test_id) AND (tests.institute_id = ( SELECT auth.uid() AS uid)))))));


--
-- Name: tests Tests are viewable by authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Tests are viewable by authenticated users" ON public.tests FOR SELECT TO authenticated USING (true);


--
-- Name: candidate_profiles Users can delete their own candidate profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete their own candidate profile" ON public.candidate_profiles FOR DELETE TO authenticated USING ((profile_id = ( SELECT auth.uid() AS uid)));


--
-- Name: institute_profiles Users can delete their own institute profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete their own institute profile" ON public.institute_profiles FOR DELETE TO authenticated USING ((profile_id = ( SELECT auth.uid() AS uid)));


--
-- Name: profiles Users can delete their own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete their own profile" ON public.profiles FOR DELETE TO authenticated USING ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: user_sessions Users can delete their own sessions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete their own sessions" ON public.user_sessions FOR DELETE USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: candidate_profiles Users can insert their own candidate profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can insert their own candidate profile" ON public.candidate_profiles FOR INSERT TO authenticated WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));


--
-- Name: institute_profiles Users can insert their own institute profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can insert their own institute profile" ON public.institute_profiles FOR INSERT TO authenticated WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));


--
-- Name: profiles Users can insert their own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: candidate_profiles Users can update their own candidate profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own candidate profile" ON public.candidate_profiles FOR UPDATE TO authenticated USING ((profile_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));


--
-- Name: institute_profiles Users can update their own institute profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own institute profile" ON public.institute_profiles FOR UPDATE TO authenticated USING ((profile_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));


--
-- Name: profiles Users can update their own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: user_sessions Users can view their own sessions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own sessions" ON public.user_sessions FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: attempt_answers; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.attempt_answers ENABLE ROW LEVEL SECURITY;

--
-- Name: candidate_profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.candidate_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: institute_profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.institute_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: options; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.options ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: question_tags; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.question_tags ENABLE ROW LEVEL SECURITY;

--
-- Name: questions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

--
-- Name: tags; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

--
-- Name: test_attempts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.test_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: tests; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;

--
-- Name: user_sessions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION check_username_available(p_username text, p_user_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.check_username_available(p_username text, p_user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.check_username_available(p_username text, p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.check_username_available(p_username text, p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.check_username_available(p_username text, p_user_id uuid) TO service_role;


--
-- Name: FUNCTION get_candidate_home_stats(p_profile_id uuid); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.get_candidate_home_stats(p_profile_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.get_candidate_home_stats(p_profile_id uuid) TO anon;
GRANT ALL ON FUNCTION public.get_candidate_home_stats(p_profile_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_candidate_home_stats(p_profile_id uuid) TO service_role;


--
-- Name: FUNCTION get_institute_home_stats(p_profile_id uuid); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.get_institute_home_stats(p_profile_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.get_institute_home_stats(p_profile_id uuid) TO anon;
GRANT ALL ON FUNCTION public.get_institute_home_stats(p_profile_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_institute_home_stats(p_profile_id uuid) TO service_role;


--
-- Name: FUNCTION grade_attempt(p_attempt_id uuid); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.grade_attempt(p_attempt_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.grade_attempt(p_attempt_id uuid) TO anon;
GRANT ALL ON FUNCTION public.grade_attempt(p_attempt_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.grade_attempt(p_attempt_id uuid) TO service_role;


--
-- Name: FUNCTION grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) TO postgres;
GRANT ALL ON FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) TO anon;
GRANT ALL ON FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) TO authenticated;
GRANT ALL ON FUNCTION public.grade_attempt_v2(p_attempt_id uuid, p_final_time_spent integer) TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_new_user() TO anon;
GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION handle_session_sync(); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.handle_session_sync() TO postgres;
GRANT ALL ON FUNCTION public.handle_session_sync() TO anon;
GRANT ALL ON FUNCTION public.handle_session_sync() TO authenticated;
GRANT ALL ON FUNCTION public.handle_session_sync() TO service_role;


--
-- Name: FUNCTION init_test_attempt(p_test_id uuid); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.init_test_attempt(p_test_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.init_test_attempt(p_test_id uuid) TO anon;
GRANT ALL ON FUNCTION public.init_test_attempt(p_test_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.init_test_attempt(p_test_id uuid) TO service_role;


--
-- Name: FUNCTION revoke_session(p_session_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.revoke_session(p_session_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.revoke_session(p_session_id uuid) TO anon;
GRANT ALL ON FUNCTION public.revoke_session(p_session_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.revoke_session(p_session_id uuid) TO service_role;


--
-- Name: FUNCTION revoke_sessions_batch(p_session_ids uuid[]); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) TO postgres;
GRANT ALL ON FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) TO anon;
GRANT ALL ON FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) TO authenticated;
GRANT ALL ON FUNCTION public.revoke_sessions_batch(p_session_ids uuid[]) TO service_role;


--
-- Name: FUNCTION save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer) TO anon;
GRANT ALL ON FUNCTION public.save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer) TO authenticated;
GRANT ALL ON FUNCTION public.save_answer(p_attempt_id uuid, p_question_id uuid, p_selected_option_ids uuid[], p_time_spent_seconds integer) TO service_role;


--
-- Name: FUNCTION save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) TO postgres;
GRANT ALL ON FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) TO anon;
GRANT ALL ON FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) TO authenticated;
GRANT ALL ON FUNCTION public.save_test_v2(p_test_id uuid, p_settings jsonb, p_questions jsonb[], p_status text) TO service_role;


--
-- Name: FUNCTION set_updated_at(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.set_updated_at() TO anon;
GRANT ALL ON FUNCTION public.set_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.set_updated_at() TO service_role;


--
-- Name: FUNCTION sync_candidate_profile(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.sync_candidate_profile() TO anon;
GRANT ALL ON FUNCTION public.sync_candidate_profile() TO authenticated;
GRANT ALL ON FUNCTION public.sync_candidate_profile() TO service_role;


--
-- Name: FUNCTION sync_institute_profile(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.sync_institute_profile() TO anon;
GRANT ALL ON FUNCTION public.sync_institute_profile() TO authenticated;
GRANT ALL ON FUNCTION public.sync_institute_profile() TO service_role;


--
-- Name: FUNCTION sync_user_session(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.sync_user_session() TO anon;
GRANT ALL ON FUNCTION public.sync_user_session() TO authenticated;
GRANT ALL ON FUNCTION public.sync_user_session() TO service_role;


--
-- Name: TABLE attempt_answers; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.attempt_answers TO anon;
GRANT ALL ON TABLE public.attempt_answers TO authenticated;
GRANT ALL ON TABLE public.attempt_answers TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: TABLE test_attempts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.test_attempts TO anon;
GRANT ALL ON TABLE public.test_attempts TO authenticated;
GRANT ALL ON TABLE public.test_attempts TO service_role;


--
-- Name: TABLE attempt_details; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.attempt_details TO anon;
GRANT ALL ON TABLE public.attempt_details TO authenticated;
GRANT ALL ON TABLE public.attempt_details TO service_role;


--
-- Name: TABLE candidate_profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.candidate_profiles TO anon;
GRANT ALL ON TABLE public.candidate_profiles TO authenticated;
GRANT ALL ON TABLE public.candidate_profiles TO service_role;


--
-- Name: TABLE institute_profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.institute_profiles TO anon;
GRANT ALL ON TABLE public.institute_profiles TO authenticated;
GRANT ALL ON TABLE public.institute_profiles TO service_role;


--
-- Name: TABLE options; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.options TO anon;
GRANT ALL ON TABLE public.options TO authenticated;
GRANT ALL ON TABLE public.options TO service_role;


--
-- Name: TABLE question_tags; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.question_tags TO anon;
GRANT ALL ON TABLE public.question_tags TO authenticated;
GRANT ALL ON TABLE public.question_tags TO service_role;


--
-- Name: TABLE questions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.questions TO anon;
GRANT ALL ON TABLE public.questions TO authenticated;
GRANT ALL ON TABLE public.questions TO service_role;


--
-- Name: TABLE tags; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tags TO anon;
GRANT ALL ON TABLE public.tags TO authenticated;
GRANT ALL ON TABLE public.tags TO service_role;


--
-- Name: TABLE tag_performance; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tag_performance TO anon;
GRANT ALL ON TABLE public.tag_performance TO authenticated;
GRANT ALL ON TABLE public.tag_performance TO service_role;


--
-- Name: TABLE tests; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tests TO anon;
GRANT ALL ON TABLE public.tests TO authenticated;
GRANT ALL ON TABLE public.tests TO service_role;


--
-- Name: TABLE user_sessions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_sessions TO anon;
GRANT ALL ON TABLE public.user_sessions TO authenticated;
GRANT ALL ON TABLE public.user_sessions TO service_role;


--
-- Name: TABLE view_question_analysis; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.view_question_analysis TO anon;
GRANT ALL ON TABLE public.view_question_analysis TO authenticated;
GRANT ALL ON TABLE public.view_question_analysis TO service_role;


--
-- Name: TABLE view_test_results_detailed; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.view_test_results_detailed TO anon;
GRANT ALL ON TABLE public.view_test_results_detailed TO authenticated;
GRANT ALL ON TABLE public.view_test_results_detailed TO service_role;


--
-- Name: TABLE view_test_summary; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.view_test_summary TO anon;
GRANT ALL ON TABLE public.view_test_summary TO authenticated;
GRANT ALL ON TABLE public.view_test_summary TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- PostgreSQL database dump complete
--



--
