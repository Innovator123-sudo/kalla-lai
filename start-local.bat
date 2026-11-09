@echo off
rem ============================================================
rem  Kalla-Lai launcher (Supabase-backed)
rem  Double-click this file. No npm commands needed.
rem    1) Kalla-Lai API  -> http://127.0.0.1:8090
rem    2) Built web app  -> http://127.0.0.1:7358
rem  Logs: server\server-dev.log   Web log: web-server.log
rem
rem  Admin sign-in:
rem    ID       : novacane232
rem    Password : SUPABASE_ADMIN_PASSWORD in server\.env
rem  (The API also accepts the full email novacane232@kallalai.app)
rem ============================================================

cd /d "%~dp0"

rem --- API: only start it when nothing is already answering ---
powershell -NoProfile -Command "if ((Invoke-WebRequest 'http://127.0.0.1:8090/healthz' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200) { exit 0 } else { exit 1 }" >nul 2>&1
if %errorlevel%==0 (
  echo  API already running on http://127.0.0.1:8090
) else (
  start "KallaLai API" /min cmd /c "cd server && npm run dev > server-dev.log 2>&1"
  echo  API starting...
)

rem --- Static web server for build\web (skip if already running) ---
rem serve-web.js serves the bundle AND proxies /v1 to the API, so the local
rem URL behaves exactly like the single-origin deployed site.
powershell -NoProfile -Command "if ((Invoke-WebRequest 'http://127.0.0.1:7358' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200) { exit 0 } else { exit 1 }" >nul 2>&1
if %errorlevel%==0 (
  echo  Web app already running on http://127.0.0.1:7358
) else (
  start "KallaLai Web" /min cmd /c "node serve-web.js > web-server.log 2>&1"
  echo  Web app starting...
)

echo.
echo   Web app : http://127.0.0.1:7358
echo   API     : http://127.0.0.1:8090/healthz
echo   Admin   : ID novacane232  ^(password in server\.env^)
echo.
echo   Backend : Supabase Postgres - configured in server\.env
echo   (Wait ~10 seconds after a cold start, then open the site.)
echo.
