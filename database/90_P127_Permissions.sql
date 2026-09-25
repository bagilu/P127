BEGIN;
ALTER TABLE public."TblP127Editor" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127Place" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127Route" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127Journey" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127Post" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127PostTranslation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127PostPlace" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127PostRoute" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127Media" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127MediaTranslation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TblP127Reaction" ENABLE ROW LEVEL SECURITY;

-- Application tables are RPC-only: no anon/authenticated table policies or privileges.
-- Shared Storage exception: only P127 policies and bucket row are created; existing grants/policies are untouched.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('p127-media','p127-media',false,15728640,ARRAY['image/jpeg','image/png','image/webp','application/pdf'])
 ON CONFLICT(id) DO NOTHING;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM storage.buckets WHERE id='p127-media' AND public) THEN RAISE EXCEPTION 'P127: existing bucket must be private; stop and inspect'; END IF;
END $$;
DROP POLICY IF EXISTS "P127 media read" ON storage.objects;
CREATE POLICY "P127 media read" ON storage.objects FOR SELECT TO anon,authenticated
 USING(bucket_id='p127-media' AND public."P127MediaReadable"(name));
DROP POLICY IF EXISTS "P127 media insert" ON storage.objects;
CREATE POLICY "P127 media insert" ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='p127-media' AND public."P127IsEditor"());
DROP POLICY IF EXISTS "P127 media delete" ON storage.objects;
CREATE POLICY "P127 media delete" ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id='p127-media' AND public."P127IsEditor"());
DROP POLICY IF EXISTS "P127 guard select" ON storage.objects;
CREATE POLICY "P127 guard select" ON storage.objects AS RESTRICTIVE FOR SELECT TO anon,authenticated
USING(bucket_id <> 'p127-media' OR (public."P127MediaReadable"(name)));
DROP POLICY IF EXISTS "P127 guard insert" ON storage.objects;
CREATE POLICY "P127 guard insert" ON storage.objects AS RESTRICTIVE FOR INSERT TO anon,authenticated
WITH CHECK(bucket_id <> 'p127-media' OR (public."P127IsEditor"()));
DROP POLICY IF EXISTS "P127 guard delete" ON storage.objects;
CREATE POLICY "P127 guard delete" ON storage.objects AS RESTRICTIVE FOR DELETE TO anon,authenticated
USING(bucket_id <> 'p127-media' OR (public."P127IsEditor"()));
DROP POLICY IF EXISTS "P127 guard update" ON storage.objects;
CREATE POLICY "P127 guard update" ON storage.objects AS RESTRICTIVE FOR UPDATE TO anon,authenticated
USING(bucket_id <> 'p127-media' OR (false));

REVOKE ALL ON TABLE public."TblP127Editor" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127Place" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127Route" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127Journey" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127Post" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127PostTranslation" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127PostPlace" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127PostRoute" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127Media" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127MediaTranslation" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public."TblP127Reaction" FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public."P127IsEditor"() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127IsEditor"() TO anon, authenticated;
REVOKE ALL ON FUNCTION public."P127MediaReadable"(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127MediaReadable"(text) TO anon, authenticated;
REVOKE ALL ON FUNCTION public."P127GetContent"(boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127GetContent"(boolean) TO anon, authenticated;
REVOKE ALL ON FUNCTION public."P127SavePost"(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127SavePost"(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public."P127SaveCatalog"(text,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127SaveCatalog"(text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public."P127RegisterMedia"(uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127RegisterMedia"(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public."P127SaveMedia"(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127SaveMedia"(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public."P127ForgetMedia"(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127ForgetMedia"(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public."P127Thank"(uuid,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public."P127Thank"(uuid,uuid) TO anon, authenticated;

COMMIT;
