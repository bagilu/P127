BEGIN;
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
COMMIT;
