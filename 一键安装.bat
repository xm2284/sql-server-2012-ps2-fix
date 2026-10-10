@echo off
chcp 65001 >nul
title SQL Server 2012 Patch
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
