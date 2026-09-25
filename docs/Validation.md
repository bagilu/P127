# V0.3 驗證紀錄 · 2026-09-25

在 Chromium 與 PGlite 的隔離測試環境通過：

- 真實 P127 SQL 經由模擬 Supabase HTTP 驗證登入、雙語編輯、發布、媒體登記／上傳流程、預覽、感謝去重、目錄更新、登出。
- 舊 config.js 無 P130 設定仍顯示正確三個入口。
- 自訂 HTTPS 入口與忘記密碼路徑正常；javascript URL 被拒絕。
- 非編輯者登入後無管理介面。
- 390px 手機登入及編輯介面無水平溢出；登入畫面已目視檢查。
- 完整唯讀健康檢查 SQL 可執行；瀏覽器無 JavaScript error。

P130 路由與 APP_URL 已依其 GitHub 原始碼核對。測試不寄送真實驗證信、不使用正式帳密，也不操作正式 Supabase 資料。P130 真實寄信與密碼重設不在此次測試範圍。

## 重現

使用 Node.js、Playwright、Chromium 與 @electric-sql/pglite。
在 repo 根目錄執行 `node tests/integration.test.mjs`，可用環境變數 `P127_PLAYWRIGHT_MODULE`、`P127_PGLITE_MODULE` 指定模組絕對路徑，`P127_CHROMIUM_PATH` 指定 Chromium 執行檔。測試會在 localhost:8127 啟動網站，並輸出截圖至忽略版控的 `test-output/`。
