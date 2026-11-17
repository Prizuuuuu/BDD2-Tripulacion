@echo off
chcp 65001 >nul
set T=C:\Users\Dell\Proyectos\herramientas
if not exist "%T%" mkdir "%T%"
cd /d "%T%"
echo Descargando Java 11, driver de MySQL y Pentaho 9.4 en %T% ...
echo El avance queda en %T%\log_descargas.txt
call :main > "%T%\log_descargas.txt" 2>&1
echo Terminado. Revisa log_descargas.txt
exit /b

:main
echo [1/3] Java 11 (Eclipse Temurin)
if not exist jdk11.zip curl -L --fail -o jdk11.zip "https://api.adoptium.net/v3/binary/latest/11/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
tar -xf jdk11.zip
echo [2/3] Driver JDBC de MySQL
if not exist mysql-connector-j-8.4.0.jar curl -L --fail -o mysql-connector-j-8.4.0.jar "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar"
echo [3/3] Pentaho Data Integration CE 9.4
if not exist pdi-ce-9.4.zip curl -L --fail -o pdi-ce-9.4.zip "https://repo.orl.eng.hitachivantara.com/artifactory/pnt-mvn/org/pentaho/di/pdi-ce/9.4.0.0-343/pdi-ce-9.4.0.0-343.zip"
if not exist pdi-ce-9.4.zip curl -L --fail -o pdi-ce-9.4.zip "https://repo.orl.eng.hitachivantara.com/artifactory/pnt-mvn/pentaho/pdi-ce/9.4.0.0-343/pdi-ce-9.4.0.0-343.zip"
if not exist pdi-ce-9.4.zip curl -L --fail -o pdi-ce-9.4.zip "https://github.com/ambientelivre/legacy-pentaho-ce/releases/download/pdi-ce-9.4.0.0-343/pdi-ce-9.4.0.0-343.zip"
tar -xf pdi-ce-9.4.zip
copy /y mysql-connector-j-8.4.0.jar data-integration\lib\
dir /b
echo DESCARGAS_OK
exit /b
