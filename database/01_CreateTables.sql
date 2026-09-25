BEGIN;
CREATE TABLE IF NOT EXISTS public."TblP127Editor" (
 "UserID" uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 "IsActive" boolean NOT NULL DEFAULT true, "CreatedAt" timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public."TblP127Place" (
 "PlaceID" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "Slug" text NOT NULL UNIQUE CHECK ("Slug" ~ '^[a-z0-9-]{1,80}$'),
 "TitleZh" text NOT NULL CHECK (length("TitleZh") BETWEEN 1 AND 160), "TitleEn" text NOT NULL DEFAULT '' CHECK(length("TitleEn") <= 240),
 "AddressZh" text NOT NULL DEFAULT '', "AddressEn" text NOT NULL DEFAULT '', "OfficialURL" text NOT NULL DEFAULT '' CHECK("OfficialURL"='' OR "OfficialURL" ~ '^https://'),
 "SortOrder" integer NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS public."TblP127Route" (
 "RouteID" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "Slug" text NOT NULL UNIQUE CHECK ("Slug" ~ '^[a-z0-9-]{1,80}$'),
 "TitleZh" text NOT NULL, "TitleEn" text NOT NULL DEFAULT '',
 "FromPlaceID" uuid NOT NULL REFERENCES public."TblP127Place"("PlaceID"), "ToPlaceID" uuid NOT NULL REFERENCES public."TblP127Place"("PlaceID"),
 "SortOrder" integer NOT NULL DEFAULT 0, CHECK ("FromPlaceID"<>"ToPlaceID"));
CREATE TABLE IF NOT EXISTS public."TblP127Journey" (
 "JourneyID" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "TitleZh" text NOT NULL, "TitleEn" text NOT NULL DEFAULT '',
 "Year" integer NOT NULL CHECK("Year" BETWEEN 1900 AND 2200),
 "PlannedStart" date, "PlannedEnd" date, "ActualStart" date, "ActualEnd" date,
 "Status" text NOT NULL DEFAULT 'planning' CHECK("Status" IN ('planning','completed')),
 CHECK("PlannedEnd">="PlannedStart"), CHECK("ActualEnd">="ActualStart"));
CREATE TABLE IF NOT EXISTS public."TblP127Post" (
 "PostID" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "Slug" text NOT NULL UNIQUE CHECK("Slug" ~ '^[a-z0-9-]{1,80}$'),
 "Category" text NOT NULL CHECK("Category" IN ('about','mountains','routes','journal','prepare','books')),
 "Status" text NOT NULL DEFAULT 'draft' CHECK("Status" IN ('draft','published','private')),
 "JourneyID" uuid REFERENCES public."TblP127Journey"("JourneyID") ON DELETE SET NULL,
 "RecordDate" date, "CheckedAt" date, "SortOrder" integer NOT NULL DEFAULT 0,
 "Revision" integer NOT NULL DEFAULT 1, "CreatedAt" timestamptz NOT NULL DEFAULT now(), "UpdatedAt" timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public."TblP127PostTranslation" (
 "PostID" uuid NOT NULL REFERENCES public."TblP127Post"("PostID") ON DELETE CASCADE,
 "Language" text NOT NULL CHECK("Language" IN ('zh','en')), "Title" text NOT NULL CHECK(length("Title") BETWEEN 1 AND 240),
 "Summary" text NOT NULL DEFAULT '' CHECK(length("Summary")<=1200),
 "IsPublished" boolean NOT NULL DEFAULT false,
 "Blocks" jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof("Blocks")='array' AND jsonb_array_length("Blocks")<=150),
 PRIMARY KEY("PostID","Language"));
CREATE TABLE IF NOT EXISTS public."TblP127PostPlace" (
 "PostID" uuid REFERENCES public."TblP127Post"("PostID") ON DELETE CASCADE,
 "PlaceID" uuid REFERENCES public."TblP127Place"("PlaceID"), PRIMARY KEY("PostID","PlaceID"));
CREATE TABLE IF NOT EXISTS public."TblP127PostRoute" (
 "PostID" uuid REFERENCES public."TblP127Post"("PostID") ON DELETE CASCADE,
 "RouteID" uuid REFERENCES public."TblP127Route"("RouteID"), PRIMARY KEY("PostID","RouteID"));
CREATE TABLE IF NOT EXISTS public."TblP127Media" (
 "MediaID" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "PostID" uuid NOT NULL REFERENCES public."TblP127Post"("PostID") ON DELETE CASCADE,
 "Path" text NOT NULL UNIQUE, "MimeType" text NOT NULL CHECK("MimeType" IN ('image/jpeg','image/png','image/webp','application/pdf')),
 "OriginalName" text NOT NULL CHECK(length("OriginalName")<=240), "FocusX" integer NOT NULL DEFAULT 50 CHECK("FocusX" BETWEEN 0 AND 100),
 "FocusY" integer NOT NULL DEFAULT 50 CHECK("FocusY" BETWEEN 0 AND 100), "CreatedAt" timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public."TblP127MediaTranslation" (
 "MediaID" uuid REFERENCES public."TblP127Media"("MediaID") ON DELETE CASCADE,
 "Language" text CHECK("Language" IN ('zh','en')), "Caption" text NOT NULL DEFAULT '' CHECK(length("Caption")<=1200),
 "Alt" text NOT NULL DEFAULT '' CHECK(length("Alt")<=500), PRIMARY KEY("MediaID","Language"));
CREATE TABLE IF NOT EXISTS public."TblP127Reaction" (
 "PostID" uuid REFERENCES public."TblP127Post"("PostID") ON DELETE CASCADE,
 "VisitorID" uuid NOT NULL, "CreatedAt" timestamptz NOT NULL DEFAULT now(), PRIMARY KEY("PostID","VisitorID"));
COMMIT;
