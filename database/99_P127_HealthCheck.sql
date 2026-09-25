-- Read-only; P127 metadata only.
WITH expected(name) AS (VALUES ('TblP127Editor'),('TblP127Place'),('TblP127Route'),('TblP127Journey'),('TblP127Post'),('TblP127PostTranslation'),('TblP127PostPlace'),('TblP127PostRoute'),('TblP127Media'),('TblP127MediaTranslation'),('TblP127Reaction'))
SELECT e.name, c.oid IS NOT NULL AS table_exists, COALESCE(c.relrowsecurity,false) AS rls_enabled,
 CASE WHEN c.oid IS NOT NULL THEN NOT has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE') END AS anon_closed,
 CASE WHEN c.oid IS NOT NULL THEN NOT has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE') END AS authenticated_closed
FROM expected e LEFT JOIN pg_class c ON c.relname=e.name AND c.relnamespace='public'::regnamespace;
WITH expected(signature,allow_anon) AS (VALUES ('public."P127IsEditor"()',true),('public."P127MediaReadable"(text)',true),('public."P127GetContent"(boolean)',true),('public."P127SavePost"(jsonb)',false),('public."P127SaveCatalog"(text,jsonb)',false),('public."P127RegisterMedia"(uuid,text,text)',false),('public."P127SaveMedia"(jsonb)',false),('public."P127ForgetMedia"(uuid)',false),('public."P127Thank"(uuid,uuid)',true))
SELECT e.signature,p.oid IS NOT NULL AS exists,p.prosecdef AS security_definer,p.proconfig,
 CASE WHEN p.oid IS NOT NULL THEN has_function_privilege('anon',p.oid,'EXECUTE')=e.allow_anon END AS anon_correct,
 CASE WHEN p.oid IS NOT NULL THEN has_function_privilege('authenticated',p.oid,'EXECUTE') END AS authenticated_can_execute,
 NOT EXISTS(SELECT 1 FROM aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE') AS public_execute_revoked
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature);
SELECT tablename,policyname,roles,cmd,permissive,qual,with_check FROM pg_policies WHERE schemaname='storage' AND policyname IN ('P127 media read','P127 media insert','P127 media delete','P127 guard select','P127 guard insert','P127 guard delete','P127 guard update');
SELECT id,NOT public AS is_private,file_size_limit,allowed_mime_types FROM storage.buckets WHERE id='p127-media';
SELECT count(*) AS active_editors FROM public."TblP127Editor" WHERE "IsActive";
SELECT "Status",count(*) FROM public."TblP127Post" GROUP BY "Status";
SELECT proname,count(*) AS overload_count FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE 'P127%' GROUP BY proname;

-- Critical columns; expect every column_exists to be true.
WITH expected(t,c) AS (VALUES ('TblP127Post','PostID'),('TblP127Post','Status'),('TblP127Post','Revision'),('TblP127Post','JourneyID'),('TblP127PostTranslation','PostID'),('TblP127PostTranslation','Language'),('TblP127PostTranslation','Blocks'),('TblP127PostTranslation','IsPublished'),('TblP127Editor','UserID'),('TblP127Editor','IsActive'),('TblP127Media','MediaID'),('TblP127Media','PostID'),('TblP127Media','Path'),('TblP127Reaction','PostID'),('TblP127Reaction','VisitorID')) SELECT t,c,EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name=t AND column_name=c) AS column_exists FROM expected;
SELECT rolname,rolbypassrls FROM pg_roles WHERE rolname='service_role';
SELECT table_name FROM information_schema.views WHERE table_schema='public' AND (table_name LIKE 'VwP127%' OR table_name LIKE 'ViewP127%');

-- v3.1 review aid: P127 routine references to other projects' named tables.
-- Expect no rows. Static text inspection only; not proof about dynamic SQL.
SELECT DISTINCT p.proname, ref[1] AS referenced_table
FROM pg_proc p
CROSS JOIN LATERAL regexp_matches(p.prosrc, '(TblP[0-9]+[A-Za-z0-9_]*)', 'g') AS ref
WHERE p.pronamespace='public'::regnamespace AND p.proname LIKE 'P127%'
 AND ref[1] !~ '^TblP127[A-Za-z_]';
-- Inspect qual/with_check above: permissive rules must target p127-media;
-- restrictive guards intentionally allow non-P127 buckets to pass through.
