const {chromium}=await import(process.env.P127_PLAYWRIGHT_MODULE||'playwright');
const {PGlite}=await import(process.env.P127_PGLITE_MODULE||'@electric-sql/pglite');
import fs from 'node:fs';import http from 'node:http';import path from 'node:path';import assert from 'node:assert/strict';
fs.mkdirSync('test-output',{recursive:true});
const db=new PGlite();
await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;CREATE SCHEMA auth;CREATE SCHEMA storage;
CREATE TABLE auth.users(id uuid PRIMARY KEY);CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
CREATE TABLE storage.objects(id uuid DEFAULT gen_random_uuid(),bucket_id text,name text);ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;GRANT USAGE ON SCHEMA public,auth,storage TO anon,authenticated;GRANT SELECT,INSERT,DELETE ON storage.objects TO anon,authenticated;
INSERT INTO auth.users VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');`);
await db.exec(fs.readFileSync('database/00_P127_Install.sql','utf8'));await db.exec(`INSERT INTO public."TblP127Editor"("UserID") VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');`);
const server=http.createServer((req,res)=>{const f=path.join(process.cwd(),req.url.split('?')[0]==='/'?'index.html':decodeURIComponent(req.url.split('?')[0]));try{res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml','.woff2':'font/woff2'})[path.extname(f)]||'application/octet-stream');res.end(fs.readFileSync(f))}catch{res.statusCode=404;res.end('Not found')}});await new Promise(r=>server.listen(8127,'127.0.0.1',r));
const browser=await chromium.launch({executablePath:process.env.P127_CHROMIUM_PATH,args:['--no-sandbox','--disable-gpu','--disable-dev-shm-usage','--no-zygote'],headless:true});
const page=await browser.newPage({viewport:{width:1440,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
const token=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')+'.'+Buffer.from(JSON.stringify({sub:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',role:'authenticated',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.test';
await page.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',body:"window.P127_CONFIG={SUPABASE_URL:'https://p127-test.invalid',SUPABASE_ANON_KEY:'anon-test'};"}));
let queue=Promise.resolve();const rpcArgs={P127IsEditor:[],P127GetContent:['p_manage'],P127SavePost:['p_doc'],P127SaveCatalog:['p_kind','p_doc'],P127RegisterMedia:['p_post','p_name','p_mime'],P127SaveMedia:['p_doc'],P127ForgetMedia:['p_media'],P127Thank:['p_post','p_visitor']};
await page.route('https://p127-test.invalid/**',route=>{queue=queue.then(async()=>{const req=route.request(),url=new URL(req.url()),body=req.headers()['content-type']?.includes('application/json')?req.postDataJSON():{};const headers={'access-control-allow-origin':'*'};try{
if(url.pathname==='/auth/v1/token'){await route.fulfill({json:{access_token:token,refresh_token:'mock-refresh',token_type:'bearer',expires_in:3600,user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'editor@example.test',aud:'authenticated',role:'authenticated'}},headers});return}
if(url.pathname==='/auth/v1/logout'){await route.fulfill({status:204,headers});return}
const editor=req.headers().authorization==='Bearer '+token;await db.exec('RESET ROLE');await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[editor?'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa':'']);await db.exec('SET ROLE '+(editor?'authenticated':'anon'));
if(url.pathname.startsWith('/rest/v1/rpc/')){const name=url.pathname.split('/').pop(),keys=rpcArgs[name];const result=await db.query(`SELECT public."${name}"(${keys.map((_,i)=>'$'+(i+1)).join(',')}) AS result`,keys.map(k=>body[k]));await route.fulfill({json:result.rows[0].result,headers});return}
if(req.method()==='GET'&&url.pathname.includes('/storage/v1/object/sign/')){await route.fulfill({contentType:'image/png',body:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII=','base64'),headers});return}
if(url.pathname.includes('/storage/v1/object/sign/')){await route.fulfill({json:{signedURL:'/object/sign/p127-media/test.png?token=mock'},headers});return}
if(url.pathname.startsWith('/storage/v1/object/')){await route.fulfill({json:{Key:'p127-media/test'},headers});return}
throw Error('Unhandled '+url.pathname)
}catch(e){await route.fulfill({status:400,json:{message:e.message,code:'P127_TEST'},headers})}})});
await page.goto('http://localhost:8127/#admin');await page.locator('#login').waitFor();
assert.equal(await page.locator('.account-links a').count(),3);
assert.equal(await page.locator('.account-links a').nth(1).getAttribute('href'),'https://bagilu.github.io/P130/forgot-password.html');
assert.equal(await page.locator('.account-links a').first().getAttribute('target'),'_blank');
await page.setViewportSize({width:390,height:844});assert(!(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1)),'mobile login overflow');
await page.screenshot({path:'test-output/P127_V03_Login.png',fullPage:true});
await page.setViewportSize({width:1440,height:1000});
await page.locator('[name=email]').fill('editor@example.test');await page.locator('[name=password]').fill('test-password');await page.locator('#login button').click();await page.locator('#new-item').waitFor();
await page.locator('#new-item').click();await page.locator('[name=Title]').fill('測試旅程 <script>alert(1)</script>');await page.locator('[name=Summary]').fill('一段測試文字。');await page.locator('#add-block').click();await page.locator('[data-key=text]').fill('走過四山，留下旅程。');await page.locator('#post-form [type=submit]').click();await page.waitForFunction(()=>document.querySelector('#toast').textContent.startsWith('已儲存。'));await page.locator('#post-form').waitFor();
assert.equal(await page.locator('[name=Title]').inputValue(),'測試旅程 <script>alert(1)</script>');
const pairKey=await page.locator('[data-key=pairKey]').first().inputValue();await page.locator('[data-language=en]').click();await page.locator('[name=Title]').fill('A test journey');await page.locator('#copy-structure').click();await page.locator('[data-key=text]').fill('A quiet journey.');await page.locator('[data-key=pairKey]').fill(pairKey);await page.locator('[name=IsPublished]').check();await page.locator('[name=Status]').selectOption('published');await page.locator('#post-form [type=submit]').click();await page.waitForTimeout(250);
await page.locator('[data-language=zh]').click();await page.locator('[name=IsPublished]').check();await page.locator('#post-form [type=submit]').click();await page.waitForTimeout(250);
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII=','base64');
await page.locator('#upload').setInputFiles({name:'test.png',mimeType:'image/png',buffer:png});await page.locator('.media-item').waitFor();await page.locator('#add-block').click();await page.locator('[data-key=type]').last().selectOption('image');await page.locator('[data-key=mediaId]').selectOption({label:'test.png'});await page.locator('#post-form [type=submit]').click();await page.waitForTimeout(300);
await page.locator('#show-preview').click();await page.locator('#preview[open]').waitFor();await page.locator('#preview-size').click();assert(await page.locator('#preview-content').evaluate(e=>e.classList.contains('phone')));await page.locator('#preview-close').click();
await page.evaluate(()=>document.fonts.ready);await page.screenshot({path:'test-output/P127_Admin_Preview.png',fullPage:true});
const slug=await page.locator('[name=Slug]').inputValue();await page.goto('http://localhost:8127/#post/'+slug);await page.locator('#main .article h1').waitFor();assert((await page.locator('#main .article h1').textContent()).includes('<script>'));assert((await page.locator('#main .bi-pair').first().textContent()).includes('A quiet journey.'));await page.locator('#thanks').click();await page.waitForFunction(()=>document.querySelector('#thanks span').textContent==='1');await page.locator('#thanks').click();assert.equal(await page.locator('#thanks span').textContent(),'1');
await page.goto('http://localhost:8127/#admin');await page.locator('[data-tab=journeys]').click();await page.locator('[data-edit]').first().click();await page.locator('[name=TitleZh]').fill('2026・測試年度');await page.locator('#catalog button').click();await page.waitForTimeout(200);assert((await page.locator('.post-list').textContent()).includes('測試年度'));
await page.locator('[data-tab=posts]').click();await page.locator('[data-edit]').first().click();await page.evaluate(()=>{document.querySelector('#toast').style.display='none'});await page.evaluate(()=>document.fonts.ready);await page.screenshot({path:'test-output/P127_Admin_Preview.png',fullPage:true});
await page.setViewportSize({width:390,height:844});assert(!(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1)),'mobile editor overflow');
await page.locator('#logout').click();await page.locator('#login').waitFor();
// Config override and fail-closed URL handling, with existing config lacking the field tested above.
await page.evaluate(()=>{window.P127_CONFIG.P130_ACCOUNT_CENTER_URL='https://example.test/accounts/'});
await page.goto('http://localhost:8127/#home');await page.goto('http://localhost:8127/#admin');await page.locator('#login').waitFor();
assert.equal(await page.locator('.account-links a').nth(1).getAttribute('href'),'https://example.test/accounts/forgot-password.html');
await page.evaluate(()=>{window.P127_CONFIG.P130_ACCOUNT_CENTER_URL='javascript:alert(1)'});
await page.goto('http://localhost:8127/#home');await page.goto('http://localhost:8127/#admin');await page.locator('#login').waitFor();assert.equal(await page.locator('.account-links a').count(),0);
await page.evaluate(()=>{delete window.P127_CONFIG.P130_ACCOUNT_CENTER_URL});
await db.exec('RESET ROLE');await db.exec('UPDATE public."TblP127Editor" SET "IsActive"=false');
await page.locator('[name=email]').fill('editor@example.test');await page.locator('[name=password]').fill('test-password');await page.locator('#login button').click();
await page.locator('#logout').waitFor();assert.equal(await page.locator('#new-item').count(),0);assert((await page.locator('#main').textContent()).includes('Editing access required'));
await db.exec('RESET ROLE');await db.exec(fs.readFileSync('database/99_P127_HealthCheck.sql','utf8'));
console.log('PASS account links, mobile layout, URL overrides, unsafe URL rejected, non-editor denied, read-only health check.');
console.log('PASS real SQL behind mocked HTTP: login, create, bilingual save, publish, upload, preview, escaped rendering, thanks dedup, catalog update, logout.');console.log('Browser errors:',errors);assert.equal(errors.length,0);await browser.close();server.close();await db.close();
