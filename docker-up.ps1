# Start Symfony + MySQL with Docker Compose (detached)
Set-Location $PSScriptRoot
docker compose up -d --build
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "App:      http://localhost:8080"
    Write-Host "Products: http://localhost:8080/product"
    Write-Host ""
    Write-Host "Stop: docker compose down"
}
