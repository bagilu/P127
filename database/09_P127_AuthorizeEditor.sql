-- Run manually AFTER 00 install; replace UUID with your existing Authentication > Users UID.
-- No account creation, password changes, or shared Auth settings are performed.
BEGIN;
DO $$
DECLARE editor_id uuid := '00000000-0000-0000-0000-000000000000';
BEGIN
 IF editor_id='00000000-0000-0000-0000-000000000000' THEN RAISE EXCEPTION '請先填入您既有 Auth 帳號的 UUID'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=editor_id) THEN RAISE EXCEPTION 'Auth user not found'; END IF;
 INSERT INTO public."TblP127Editor"("UserID") VALUES(editor_id) ON CONFLICT("UserID") DO UPDATE SET "IsActive"=true;
END $$;
COMMIT;
