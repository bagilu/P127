# P127 台灣四山之路 · V0.3

Taiwan Four Mountains Route · SBI-P-SDS v3.1

中英併呈的行旅紀錄網站，使用 GitHub Pages 與實驗室共用 Supabase Auth。

- P127 保留自己的登入與獨立 session (`p127-auth-token`)。
- P130 負責註冊、驗證、忘記／修改密碼與帳號設定。
- P127 編輯資格由 `TblP127Editor` 獨立管理；註冊不會自動取得權限。
- 公開內容透過 RPC 讀取，私有照片使用短效簽名連結。

請閱讀 [部署與改版說明](docs/Deployment.md)、[驗證紀錄](docs/Validation.md)。

## 檔案

根目錄為可直接部署的靜態前端；`assets/` 為程式與樣式，`fonts/` 為自帶字型，`database/` 為 P127 專屬 SQL，`docs/` 為說明。

部署環境使用自己的 `config.js`；發行包僅含 `config-sample.js`。既有部署設定不覆蓋。
