Write-Host "=== STEP 1: Running Flutter Analyze ===" -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Error "Static analysis failed. Please fix issues before pushing."
    exit 1
}

Write-Host "=== STEP 2: Building Web Target ===" -ForegroundColor Cyan
flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) {
    Write-Error "Web compilation failed."
    exit 1
}

if ($IsWindows) {
    Write-Host "=== STEP 3: Building Windows Target ===" -ForegroundColor Cyan
    flutter build windows
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Windows compilation failed."
        exit 1
    }
}

Write-Host "=== SUCCESS: All local verification builds passed! ===" -ForegroundColor Green
