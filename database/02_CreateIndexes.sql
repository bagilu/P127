BEGIN;
CREATE INDEX IF NOT EXISTS "idx_TblP127Post_Category" ON public."TblP127Post"("Category","Status","SortOrder");
CREATE INDEX IF NOT EXISTS "idx_TblP127Post_Journey" ON public."TblP127Post"("JourneyID");
CREATE INDEX IF NOT EXISTS "idx_TblP127Media_Post" ON public."TblP127Media"("PostID");
CREATE INDEX IF NOT EXISTS "idx_TblP127PostPlace_Place" ON public."TblP127PostPlace"("PlaceID");
CREATE INDEX IF NOT EXISTS "idx_TblP127PostRoute_Route" ON public."TblP127PostRoute"("RouteID");
COMMIT;
