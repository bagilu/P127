# P127 SQL 執行說明

全新部署只需依序：
1. 00_P127_Install.sql（01–08 的整合版，整個交易一併成功或失敗）。
2. 09_P127_AuthorizeEditor.sql（先填既有 Auth 帳號 UUID）。
3. 99_P127_HealthCheck.sql。

01–08 是 P-SDS 標準分檔與維護來源。不要在正式環境分次暴露剛建立但尚未 REVOKE PUBLIC 的函式；優先用 00 原子安裝。未來升版使用專用 migration。

90_P127_Permissions.sql 可重複執行，恢復本專案 RLS、Storage policies 和函式權限，不更動文章或其他專案。

健康檢查：
- 11 張表 table_exists、rls_enabled、anon_closed、authenticated_closed 均應為 true。
- 9 個 RPC exists、security_definer、anon_correct、authenticated_can_execute、public_execute_revoked 應為 true；proconfig 應包含空 search_path。
- Storage policies 應有 3 個 permissive 與 4 個 restrictive；p127-media is_private=true；file_size_limit=15728640。
- active_editors 至少 1；首次 seed public 13 篇，之後以您的編輯為準。
- overload_count 預期各 1。沒有 View 是正常的。
- 關鍵欄位 column_exists=true。service_role 為平台管理角色，通常 bypass RLS；前端不可使用它。

Storage 共用物件例外：bucket 必須存於 Supabase 的 storage.buckets，policies 必須掛在 storage.objects。僅新增/修復 P127 命名的 policies 與 bucket=p127-media 條件，不修改共用表 RLS/GRANT。restrictive guards 防止其他既有寬鬆 Storage policy 將 P127 檔案暴露；其他 bucket 不受這些 guards 限制。若既有同名 bucket 是 public，安裝會中止而非擅自變更。

在 SQL Editor 以管理角色執行。00 重跑的 ON CONFLICT DO NOTHING 不覆寫初始文章，也不會抹除新增資料。09 全零 UUID 未替換會明確報錯，整個交易回滾。
