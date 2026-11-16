# =====================================================================
# Carga del grafo de Tripulación en Neo4j AuraDB
# Uso (PowerShell, en la carpeta avance3, con Docker Desktop abierto):
#   powershell -ExecutionPolicy Bypass -File .\cargar_aura.ps1
# Pide la URI y la contraseña de la instancia (están en el archivo .txt que
# descarga Aura al crearla). La contraseña no se guarda en ningún archivo.
# =====================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Set-Location $PSScriptRoot

$uri = Read-Host "URI de la instancia (ej. neo4j+s://xxxxxxxx.databases.neo4j.io)"
$usuario = Read-Host "Usuario (Enter = neo4j)"
if (-not $usuario) { $usuario = "neo4j" }
$seguro = Read-Host "Contraseña" -AsSecureString
$clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro))

$imagen = "neo4j:5-enterprise"
$cypher = (Resolve-Path .\cypher).Path

function Ejecutar($archivo, $descripcion) {
    Write-Host ""
    Write-Host "== $descripcion ($archivo)" -ForegroundColor Cyan
    docker run --rm -e NEO4J_ACCEPT_LICENSE_AGREEMENT=eval -e NEO4J_USERNAME=$usuario -e NEO4J_PASSWORD=$clave `
        -v "${cypher}:/cypher:ro" $imagen cypher-shell -a $uri -f "/cypher/$archivo"
    if ($LASTEXITCODE -ne 0) { Write-Host "Falló $archivo" -ForegroundColor Red; exit 1 }
}

Ejecutar "01_restricciones.cypher" "Restricciones"
Ejecutar "02_nodos.cypher" "Nodos (puede tardar 1-2 minutos)"
Ejecutar "03_relaciones.cypher" "Relaciones (puede tardar 2-4 minutos)"
Ejecutar "04_verificacion.cypher" "Verificación de volúmenes y coherencia"
Write-Host ""
Write-Host "Listo. Abre la instancia en console.neo4j.io y ejecuta las consultas de 05_consultas.cypher." -ForegroundColor Green
