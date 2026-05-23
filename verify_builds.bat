@echo off
echo === STEP 1: Running Flutter Analyze ===
call flutter analyze
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Static analysis failed. Fix issues before pushing.
    pause
    exit /b %ERRORLEVEL%
)

echo === STEP 2: Building Web Target ===
call flutter build web --release --no-wasm-dry-run
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Web build failed.
    pause
    exit /b %ERRORLEVEL%
)

echo === STEP 3: Building Windows Target ===
call flutter build windows
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Windows build failed.
    pause
    exit /b %ERRORLEVEL%
)

echo ========================================================
echo SUCCESS: All local builds compiled cleanly!
echo ========================================================
pause
