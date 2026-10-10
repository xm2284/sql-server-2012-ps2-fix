@echo off
chcp 65001 >nul
title SQL Server 2012 Patch - PowerShell 2.0 Fix
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
