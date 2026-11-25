@echo off
setlocal
where node >nul 2>nul
if errorlevel 1 (
    echo Node.js was not found. Install Node.js, then open a new terminal.
    pause
    exit /b 1
)
for /f "tokens=1 delims=." %%v in ('node -p "process.versions.node"') do set "NODE_MAJOR=%%v"
if %NODE_MAJOR% LSS 18 (
    echo VoiceDesk requires Node.js 18 or newer. Update Node.js, then open a new terminal.
    pause
    exit /b 1
)
if not defined VOICEDESK_MODEL (
    set "VOICEDESK_MODEL=qwen3.5:4b"
)
where ollama >nul 2>nul
if errorlevel 1 (
    echo Ollama was not found. Install Ollama, then run: ollama pull %VOICEDESK_MODEL%
    pause
    exit /b 1
)
node "%~dp0ai-service\server.mjs"
if errorlevel 1 (
    echo The VoiceDesk AI service stopped with an error.
    pause
    exit /b 1
)
