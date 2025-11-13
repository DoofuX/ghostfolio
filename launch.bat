@echo off
echo Starting Ghostfolio Development Environment...
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running. Please start Docker Desktop and try again.
    pause
    exit /b 1
)

REM Check if containers are already running
echo Checking Docker containers...
docker ps --filter "name=gf-postgres-dev" --format "{{.Names}}" 2>nul | findstr /C:"gf-postgres-dev" >nul
set POSTGRES_RUNNING=%errorlevel%
docker ps --filter "name=gf-redis-dev" --format "{{.Names}}" 2>nul | findstr /C:"gf-redis-dev" >nul
set REDIS_RUNNING=%errorlevel%

REM Check if both containers are running
if %POSTGRES_RUNNING% equ 0 (
    if %REDIS_RUNNING% equ 0 (
        echo Docker containers are already running.
        echo.
        goto :start_services
    )
)

REM Check for stopped/existing containers first
echo Checking for existing containers...
docker ps -a --filter "name=gf-postgres-dev" --format "{{.Names}}" 2>nul | findstr /C:"gf-postgres-dev" >nul
if %errorlevel% equ 0 (
    echo Found existing PostgreSQL container. Cleaning up...
    docker compose -f docker/docker-compose.dev.yml down
    timeout /t 2 /nobreak >nul
)

REM Check if ports are in use
echo Checking if ports are available...
netstat -ano 2>nul | findstr ":5432" >nul
if %errorlevel% equ 0 (
    echo WARNING: Port 5432 is already in use!
    echo.
    echo Checking what's using the port:
    netstat -ano | findstr ":5432"
    echo.
    echo This might be a local PostgreSQL service or another Docker container.
    echo You may need to:
    echo   1. Stop the service: net stop postgresql-x64-XX (replace XX with version)
    echo   2. Or stop other Docker containers using this port
    echo   3. Or change the port in docker/docker-compose.dev.yml
    echo.
    set /p CONTINUE="Continue anyway? (y/n): "
    if /i not "%CONTINUE%"=="y" (
        echo Aborted.
        pause
        exit /b 1
    )
    echo.
)

REM Start Docker containers
echo Starting Docker containers...
docker compose -f docker/docker-compose.dev.yml up -d
if errorlevel 1 (
    echo.
    echo ERROR: Failed to start Docker containers.
    echo.
    echo Detailed error information:
    docker compose -f docker/docker-compose.dev.yml ps
    echo.
    echo Attempting to clean up and restart...
    docker compose -f docker/docker-compose.dev.yml down
    timeout /t 3 /nobreak >nul
    docker compose -f docker/docker-compose.dev.yml up -d
    if errorlevel 1 (
        echo.
        echo ========================================
        echo FAILED TO START CONTAINERS
        echo ========================================
        echo.
        echo Port 5432 (PostgreSQL) is likely already in use.
        echo.
        echo To fix this, try one of the following:
        echo.
        echo Option 1: Stop local PostgreSQL service
        echo   - Open services.msc
        echo   - Find PostgreSQL service and stop it
        echo   - Or run: net stop postgresql-x64-XX
        echo.
        echo Option 2: Check what's using the port
        echo   Run: netstat -ano ^| findstr ":5432"
        echo   Then stop the process using that PID
        echo.
        echo Option 3: Use different ports
        echo   Edit docker/docker-compose.dev.yml and change the port mapping
        echo.
        echo Option 4: Remove conflicting containers
        echo   Run: docker ps -a
        echo   Then: docker rm -f [container-id]
        echo.
        pause
        exit /b 1
    )
)
echo Docker containers started successfully.
echo.

:start_services

REM Wait a moment for containers to be ready
timeout /t 3 /nobreak >nul

REM Start the server in a new window
echo Starting API server...
start "Ghostfolio API Server" cmd /k "npm run start:server"
if errorlevel 1 (
    echo ERROR: Failed to start API server.
    pause
    exit /b 1
)

REM Wait a moment before starting the client
timeout /t 2 /nobreak >nul

REM Start the client in a new window
echo Starting client...
start "Ghostfolio Client" cmd /k "npm run start:client"
if errorlevel 1 (
    echo ERROR: Failed to start client.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Ghostfolio is starting up!
echo ========================================
echo.
echo The application will be available at:
echo   https://localhost:4200/en
echo.
echo Two new windows have been opened:
echo   - Ghostfolio API Server (backend)
echo   - Ghostfolio Client (frontend)
echo.
echo Press any key to exit this window (the application will continue running)...
pause >nul

