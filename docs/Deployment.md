# P127 V0.3 · SDS v3.1 帳號中心銜接

## 既有站點更新

本次無資料表、RPC、授權或 Storage policy 變更，不需執行 migration，也不需重跑安裝 SQL。
保留部署中的 `config.js`、Supabase URL 與公開金鑰。不得在前端放入 service_role／secret key。

`account-center-config.js` 提供公開的 P130 入口 `https://bagilu.github.io/P130/`，取自 P130 現有部署設定。
若搬遷帳號中心，可修改此公開檔案，或在 `P127_CONFIG` 設定 `P130_ACCOUNT_CENTER_URL` 覆寫。只接受 HTTPS 目錄網址，不接受帳密、query 或 fragment。無效設定會隱藏連結並顯示提示，不影響 P127 本身登入。

P130 現行首頁有「登入／註冊」頁籤，沒有獨立註冊路由。因此註冊連結先進首頁，使用者再選「註冊」；帳號設定亦進首頁，必要時再次登入。忘記密碼連至 `forgot-password.html`。
連結在新分頁開啟，不傳送 email、密碼或 session token；P127 與 P130 的登入狀態各自保存。
完成帳號處理後，使用者回 P127 登入；編輯资格仍由 `TblP127Editor` 判定。

不修改 P130 程式、共用 Auth 設定、Site URL、Redirect URLs 或 auth.users；不建立全域 Auth trigger、不自動授權其他專案。

## SQL 使用範圍

`database/` 保存 V0.2 安裝基準與本次增強的唯讀健康檢查，並非本次必須套用的 migration。
新環境才依 `database/README.md` 安裝；既有資料庫不可為此次前端升版重新初始化。
`99_P127_HealthCheck.sql` 可由管理者手動執行：检查 P127 RLS、RPC grant、Storage policy 條件與對其他專案表名的文字引用。靜態引用掃描不保證涵蓋 dynamic SQL。
`90_P127_Permissions.sql` 僅供明確需要修復 P127 授權時使用。

## 外觀與資料

保留中英段落配對與 Supabase 內容編輯方式，修正根目錄 `fonts/` 的 CSS 路徑。
文章、照片、私人內容與其他專案資料均不由此次部署修改。

## 發行包

ZIP 外層資料夾應與 ZIP 檔名相同；含根目錄前端、`database/`、`docs/`，排除 `config.js`。
