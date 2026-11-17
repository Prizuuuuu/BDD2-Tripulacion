@echo off
taskkill /f /im javaw.exe >nul 2>&1
set T=C:\Users\Dell\Proyectos\herramientas
for /d %%d in ("%T%\jdk-11*") do set PENTAHO_JAVA_HOME=%%d
set JAVA_HOME=%PENTAHO_JAVA_HOME%
cd /d "%T%\data-integration"
call Spoon.bat -file="C:\Users\Dell\Proyectos\BDD2-Tripulacion\avance4\etl\job_dm_tripulacion.kjb"
