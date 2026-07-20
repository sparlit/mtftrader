@echo off
:: ITIP Unified Control Script for Windows OS

SET COMMAND=%1

IF "%COMMAND%"=="install" (
    echo ===========================================
    echo Installing ITIP v1.0 Dependencies (Windows)
    echo ===========================================
    echo --^> Installing Python requirements...
    pip install fastapi uvicorn pydantic
    echo --^> Compiling Rust High-Performance Engine...
    cargo build --manifest-path rust/Cargo.toml --release
    echo --^> Installation Completed Successfully!
    GOTO :EOF
)

IF "%COMMAND%"=="start" (
    echo ===========================================
    echo Starting ITIP v1.0 Platform (Windows)
    echo ===========================================
    echo --^> Launching Python FastAPI Server...
    start /B python python/server.py > python_server.log 2>&1
    echo --^> Running Rust High-Performance Engine Risk Simulation...
    cargo run --manifest-path rust/Cargo.toml --release
    echo --^> Platform started successfully!
    GOTO :EOF
)

echo Usage: itip {install^|start}
echo   install : Installs all python packages and compiles the Rust engine on Windows
echo   start   : Starts the FastAPI backend and runs the Rust simulation on Windows
