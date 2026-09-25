BEGIN;
CREATE OR REPLACE FUNCTION public."P127IsEditor"() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public."TblP127Editor" WHERE "UserID"=auth.uid() AND "IsActive"); $$;
CREATE OR REPLACE FUNCTION public."P127MediaReadable"(p_path text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public."P127IsEditor"() OR EXISTS (
 SELECT 1 FROM public."TblP127Media" m JOIN public."TblP127Post" p USING("PostID")
 JOIN public."TblP127PostTranslation" t USING("PostID")
 WHERE m."Path"=p_path AND p."Status"='published' AND t."IsPublished"
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(t."Blocks") b WHERE b->>'mediaId'=m."MediaID"::text)); $$;
CREATE OR REPLACE FUNCTION public."P127GetContent"(p_manage boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF p_manage AND NOT public."P127IsEditor"() THEN RAISE EXCEPTION 'P127: editor access required'; END IF;
 SELECT jsonb_build_object(
 'posts',COALESCE((SELECT jsonb_agg(to_jsonb(p) || jsonb_build_object(
 'translations',COALESCE((SELECT jsonb_agg(t) FROM public."TblP127PostTranslation" t WHERE t."PostID"=p."PostID" AND (p_manage OR t."IsPublished")),'[]'::jsonb),
 'places',COALESCE((SELECT jsonb_agg("PlaceID") FROM public."TblP127PostPlace" WHERE "PostID"=p."PostID"),'[]'::jsonb),
 'routes',COALESCE((SELECT jsonb_agg("RouteID") FROM public."TblP127PostRoute" WHERE "PostID"=p."PostID"),'[]'::jsonb),
 'thanks',(SELECT count(*) FROM public."TblP127Reaction" WHERE "PostID"=p."PostID")) ORDER BY p."SortOrder",p."RecordDate" DESC NULLS LAST,p."CreatedAt")
 FROM public."TblP127Post" p WHERE p_manage OR (p."Status"='published' AND EXISTS(SELECT 1 FROM public."TblP127PostTranslation" t WHERE t."PostID"=p."PostID" AND t."IsPublished"))),'[]'::jsonb),
 'places',COALESCE((SELECT jsonb_agg(p ORDER BY "SortOrder") FROM public."TblP127Place" p),'[]'::jsonb),
 'routes',COALESCE((SELECT jsonb_agg(r ORDER BY "SortOrder") FROM public."TblP127Route" r),'[]'::jsonb),
 'journeys',COALESCE((SELECT jsonb_agg(j ORDER BY "Year" DESC) FROM public."TblP127Journey" j),'[]'::jsonb),
 'media',COALESCE((SELECT jsonb_agg(to_jsonb(m) || jsonb_build_object('translations',COALESCE((SELECT jsonb_agg(t) FROM public."TblP127MediaTranslation" t WHERE t."MediaID"=m."MediaID" AND (p_manage OR EXISTS(SELECT 1 FROM public."TblP127PostTranslation" pt WHERE pt."PostID"=m."PostID" AND pt."Language"=t."Language" AND pt."IsPublished"))),'[]'::jsonb)))
 FROM public."TblP127Media" m WHERE p_manage OR public."P127MediaReadable"(m."Path")),'[]'::jsonb)) INTO result;
 RETURN result;
END; $$;
CREATE OR REPLACE FUNCTION public."P127SavePost"(p_doc jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE pid uuid; t jsonb; b jsonb; seen text[] := '{}'; n integer;
BEGIN
 IF NOT public."P127IsEditor"() THEN RAISE EXCEPTION 'P127: editor access required'; END IF;
 IF p_doc IS NULL OR octet_length(p_doc::text)>600000 THEN RAISE EXCEPTION 'P127: document too large'; END IF;
 IF jsonb_typeof(p_doc->'translations') IS DISTINCT FROM 'array' OR jsonb_array_length(p_doc->'translations') NOT BETWEEN 1 AND 2 THEN RAISE EXCEPTION 'P127: invalid translations'; END IF;
 pid:=NULLIF(p_doc->>'PostID','')::uuid;
 IF pid IS NULL THEN
 INSERT INTO public."TblP127Post"("Slug","Category","Status","JourneyID","RecordDate","CheckedAt","SortOrder") VALUES
 (p_doc->>'Slug',p_doc->>'Category',p_doc->>'Status',NULLIF(p_doc->>'JourneyID','')::uuid,NULLIF(p_doc->>'RecordDate','')::date,NULLIF(p_doc->>'CheckedAt','')::date,COALESCE((p_doc->>'SortOrder')::integer,0)) RETURNING "PostID" INTO pid;
 ELSE
 UPDATE public."TblP127Post" SET "Slug"=p_doc->>'Slug',"Category"=p_doc->>'Category',"Status"=p_doc->>'Status',
 "JourneyID"=NULLIF(p_doc->>'JourneyID','')::uuid,"RecordDate"=NULLIF(p_doc->>'RecordDate','')::date,"CheckedAt"=NULLIF(p_doc->>'CheckedAt','')::date,
 "SortOrder"=COALESCE((p_doc->>'SortOrder')::integer,0),"Revision"="Revision"+1,"UpdatedAt"=now()
 WHERE "PostID"=pid AND "Revision"=(p_doc->>'Revision')::integer;
 IF NOT FOUND THEN RAISE EXCEPTION 'P127: revision conflict; reload before editing'; END IF;
 END IF;
 DELETE FROM public."TblP127PostTranslation" WHERE "PostID"=pid;
 FOR t IN SELECT value FROM jsonb_array_elements(p_doc->'translations') LOOP
 IF t->>'Language' IS NULL OR t->>'Language' NOT IN ('zh','en') OR t->>'Language'=ANY(seen) THEN RAISE EXCEPTION 'P127: invalid language'; END IF;
 seen:=array_append(seen,t->>'Language');
 IF jsonb_typeof(t->'Blocks') IS DISTINCT FROM 'array' OR jsonb_array_length(t->'Blocks')>150 THEN RAISE EXCEPTION 'P127: invalid blocks'; END IF;
 FOR b IN SELECT value FROM jsonb_array_elements(t->'Blocks') LOOP
 IF b->>'type' IS NULL OR b->>'type' NOT IN ('paragraph','heading','quote','list','image','file','link') OR length(COALESCE(b->>'text',''))>12000 THEN RAISE EXCEPTION 'P127: invalid block'; END IF;
 IF b->>'type'='link' AND (b->>'url' IS NULL OR b->>'url' !~ '^https://[^[:space:]]+$' OR length(b->>'url')>2048) THEN RAISE EXCEPTION 'P127: HTTPS link required'; END IF;
 IF b->>'type' IN ('image','file') THEN
 IF NOT EXISTS(SELECT 1 FROM public."TblP127Media" WHERE "MediaID"=NULLIF(b->>'mediaId','')::uuid AND "PostID"=pid AND ((b->>'type'='image' AND "MimeType" LIKE 'image/%') OR (b->>'type'='file' AND "MimeType"='application/pdf'))) THEN RAISE EXCEPTION 'P127: media must belong to this post'; END IF;
 END IF;
 END LOOP;
 INSERT INTO public."TblP127PostTranslation"("PostID","Language","Title","Summary","IsPublished","Blocks") VALUES
 (pid,t->>'Language',t->>'Title',COALESCE(t->>'Summary',''),COALESCE((t->>'IsPublished')::boolean,false),t->'Blocks');
 END LOOP;
 IF p_doc->>'Status'='published' AND NOT EXISTS(SELECT 1 FROM public."TblP127PostTranslation" WHERE "PostID"=pid AND "IsPublished") THEN RAISE EXCEPTION 'P127: select at least one published language'; END IF;
 DELETE FROM public."TblP127PostPlace" WHERE "PostID"=pid;
 INSERT INTO public."TblP127PostPlace" SELECT pid,value::uuid FROM jsonb_array_elements_text(COALESCE(p_doc->'places','[]')) ON CONFLICT DO NOTHING;
 DELETE FROM public."TblP127PostRoute" WHERE "PostID"=pid;
 INSERT INTO public."TblP127PostRoute" SELECT pid,value::uuid FROM jsonb_array_elements_text(COALESCE(p_doc->'routes','[]')) ON CONFLICT DO NOTHING;
 RETURN pid;
END; $$;
CREATE OR REPLACE FUNCTION public."P127SaveCatalog"(p_kind text,p_doc jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE id uuid;
BEGIN
 IF NOT public."P127IsEditor"() THEN RAISE EXCEPTION 'P127: editor access required'; END IF;
 IF p_doc IS NULL OR octet_length(p_doc::text)>16000 OR length(COALESCE(p_doc->>'TitleZh','')) NOT BETWEEN 1 AND 160 OR length(COALESCE(p_doc->>'TitleEn',''))>240 THEN RAISE EXCEPTION 'P127: invalid catalog'; END IF;
 IF p_kind='places' THEN
 id:=COALESCE(NULLIF(p_doc->>'PlaceID','')::uuid,gen_random_uuid());
 INSERT INTO public."TblP127Place" VALUES(id,p_doc->>'Slug',p_doc->>'TitleZh',COALESCE(p_doc->>'TitleEn',''),COALESCE(p_doc->>'AddressZh',''),COALESCE(p_doc->>'AddressEn',''),COALESCE(p_doc->>'OfficialURL',''),COALESCE((p_doc->>'SortOrder')::integer,0))
 ON CONFLICT("PlaceID") DO UPDATE SET "Slug"=EXCLUDED."Slug","TitleZh"=EXCLUDED."TitleZh","TitleEn"=EXCLUDED."TitleEn","AddressZh"=EXCLUDED."AddressZh","AddressEn"=EXCLUDED."AddressEn","OfficialURL"=EXCLUDED."OfficialURL","SortOrder"=EXCLUDED."SortOrder";
 ELSIF p_kind='routes' THEN
 id:=COALESCE(NULLIF(p_doc->>'RouteID','')::uuid,gen_random_uuid());
 INSERT INTO public."TblP127Route" VALUES(id,p_doc->>'Slug',p_doc->>'TitleZh',COALESCE(p_doc->>'TitleEn',''),(p_doc->>'FromPlaceID')::uuid,(p_doc->>'ToPlaceID')::uuid,COALESCE((p_doc->>'SortOrder')::integer,0))
 ON CONFLICT("RouteID") DO UPDATE SET "Slug"=EXCLUDED."Slug","TitleZh"=EXCLUDED."TitleZh","TitleEn"=EXCLUDED."TitleEn","FromPlaceID"=EXCLUDED."FromPlaceID","ToPlaceID"=EXCLUDED."ToPlaceID","SortOrder"=EXCLUDED."SortOrder";
 ELSIF p_kind='journeys' THEN
 id:=COALESCE(NULLIF(p_doc->>'JourneyID','')::uuid,gen_random_uuid());
 INSERT INTO public."TblP127Journey" VALUES(id,p_doc->>'TitleZh',COALESCE(p_doc->>'TitleEn',''),(p_doc->>'Year')::integer,NULLIF(p_doc->>'PlannedStart','')::date,NULLIF(p_doc->>'PlannedEnd','')::date,NULLIF(p_doc->>'ActualStart','')::date,NULLIF(p_doc->>'ActualEnd','')::date,p_doc->>'Status')
 ON CONFLICT("JourneyID") DO UPDATE SET "TitleZh"=EXCLUDED."TitleZh","TitleEn"=EXCLUDED."TitleEn","Year"=EXCLUDED."Year","PlannedStart"=EXCLUDED."PlannedStart","PlannedEnd"=EXCLUDED."PlannedEnd","ActualStart"=EXCLUDED."ActualStart","ActualEnd"=EXCLUDED."ActualEnd","Status"=EXCLUDED."Status";
 ELSE RAISE EXCEPTION 'P127: invalid catalog type'; END IF;
 RETURN id;
END; $$;
CREATE OR REPLACE FUNCTION public."P127RegisterMedia"(p_post uuid,p_name text,p_mime text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE mid uuid:=gen_random_uuid(); path text; ext text;
BEGIN
 IF NOT public."P127IsEditor"() THEN RAISE EXCEPTION 'P127: editor access required'; END IF;
 ext:=CASE p_mime WHEN 'image/jpeg' THEN 'jpg' WHEN 'image/png' THEN 'png' WHEN 'image/webp' THEN 'webp' WHEN 'application/pdf' THEN 'pdf' END;
 IF ext IS NULL OR p_name IS NULL OR length(p_name) NOT BETWEEN 1 AND 240 THEN RAISE EXCEPTION 'P127: unsupported file'; END IF;
 path:=p_post::text||'/'||mid::text||'.'||ext;
 INSERT INTO public."TblP127Media"("MediaID","PostID","Path","MimeType","OriginalName") VALUES(mid,p_post,path,p_mime,p_name);
 RETURN jsonb_build_object('MediaID',mid,'Path',path);
END; $$;
CREATE OR REPLACE FUNCTION public."P127SaveMedia"(p_doc jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t jsonb;
BEGIN
 IF NOT public."P127IsEditor"() THEN RAISE EXCEPTION 'P127: editor access required'; END IF;
 IF p_doc IS NULL OR octet_length(p_doc::text)>10000 OR jsonb_typeof(p_doc->'translations') IS DISTINCT FROM 'array' OR jsonb_array_length(p_doc->'translations')>2 THEN RAISE EXCEPTION 'P127: invalid media'; END IF;
 UPDATE public."TblP127Media" SET "FocusX"=(p_doc->>'FocusX')::integer,"FocusY"=(p_doc->>'FocusY')::integer WHERE "MediaID"=(p_doc->>'MediaID')::uuid;
 IF NOT FOUND THEN RAISE EXCEPTION 'P127: media not found'; END IF;
 FOR t IN SELECT value FROM jsonb_array_elements(p_doc->'translations') LOOP
 INSERT INTO public."TblP127MediaTranslation" VALUES((p_doc->>'MediaID')::uuid,t->>'Language',COALESCE(t->>'Caption',''),COALESCE(t->>'Alt',''))
 ON CONFLICT("MediaID","Language") DO UPDATE SET "Caption"=EXCLUDED."Caption","Alt"=EXCLUDED."Alt";
 END LOOP;
END; $$;
CREATE OR REPLACE FUNCTION public."P127ForgetMedia"(p_media uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public."P127IsEditor"() THEN RAISE EXCEPTION 'P127: editor access required'; END IF;
 IF EXISTS(SELECT 1 FROM public."TblP127PostTranslation" t,jsonb_array_elements(t."Blocks") b WHERE b->>'mediaId'=p_media::text) THEN RAISE EXCEPTION 'P127: remove media blocks and save both languages first'; END IF;
 DELETE FROM public."TblP127Media" WHERE "MediaID"=p_media;
END; $$;
CREATE OR REPLACE FUNCTION public."P127Thank"(p_post uuid,p_visitor uuid) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_visitor IS NULL OR NOT EXISTS(SELECT 1 FROM public."TblP127Post" p JOIN public."TblP127PostTranslation" t USING("PostID") WHERE p."PostID"=p_post AND p."Status"='published' AND t."IsPublished") THEN RAISE EXCEPTION 'P127: content unavailable'; END IF;
 INSERT INTO public."TblP127Reaction"("PostID","VisitorID") VALUES(p_post,p_visitor) ON CONFLICT DO NOTHING;
 RETURN (SELECT count(*) FROM public."TblP127Reaction" WHERE "PostID"=p_post);
END; $$;
COMMIT;
