param(
    [Parameter(Mandatory = $true)]
    [string]$machine
)

# Caminho local do log NMEA no computador remoto. Alterar para o caminho real.
$LogPath = "C:\Path\To\gps.log"

# Converte para caminho de partilha administrativa (C:\... -> \\maquina\C$\...).
$Log = "\\$machine\" + ($LogPath -replace '^([A-Za-z]):', '$1$')

# Numero de linhas do fim do log a analisar.
$TailLines = 10

if (!(Test-Path $Log)) {
    Write-Host "Log nao encontrado: $Log" -ForegroundColor Red
    exit 1
}

function Convert-NmeaCoordinate {
    param(
        [string]$Coordinate,
        [string]$Direction
    )

    if ($Direction -in @("N","S")) {
        $Degrees = [double]::Parse(
            $Coordinate.Substring(0,2),
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $Minutes = [double]::Parse(
            $Coordinate.Substring(2),
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }
    else {
        $Degrees = [double]::Parse(
            $Coordinate.Substring(0,3),
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $Minutes = [double]::Parse(
            $Coordinate.Substring(3),
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }

    $Decimal = $Degrees + ($Minutes / 60)

    if ($Direction -in @("S","W")) {
        $Decimal = -$Decimal
    }

    return $Decimal
}

# Aceita $GPRMC (so GPS) e $GNRMC (multi-GNSS, recetores mais recentes).
# Usa a ULTIMA linha encontrada, ou seja, a posicao mais recente.
$Linha = Get-Content $Log -Tail $TailLines |
         Where-Object { $_ -match '\$G[PN]RMC,' } |
         Select-Object -Last 1

if (-not $Linha) {
    Write-Host "Nenhuma linha GPRMC/GNRMC encontrada nas ultimas $TailLines linhas." -ForegroundColor Red
    exit 1
}

# Remove o que vem antes da frase NMEA e o checksum (*hh) no fim.
$Frase = $Linha.Substring($Linha.IndexOf('$')) -replace '\*[0-9A-Fa-f]{2}\s*$', ''
$Campos = $Frase.Split(',')

if ($Campos.Count -lt 7) {
    Write-Host "Linha RMC invalida." -ForegroundColor Red
    exit 1
}

# Campo 2 = estado: A = posicao valida, V = sem fix (coordenadas nao fiaveis).
if ($Campos[2] -ne 'A') {
    Write-Host "O GPS nao tem uma posicao valida (estado '$($Campos[2])', sem fix)." -ForegroundColor Red
    Write-Host "Linha: $Linha" -ForegroundColor DarkGray
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Campos[3]) -or [string]::IsNullOrWhiteSpace($Campos[5])) {
    Write-Host "A linha RMC nao contem coordenadas." -ForegroundColor Red
    exit 1
}

# Hora UTC (campo 1, hhmmss) e data (campo 9, ddmmyy) do ultimo fix, se existirem.
$HoraFix = "N/A"
if ($Campos.Count -gt 9 -and $Campos[1].Length -ge 6 -and $Campos[9].Length -eq 6) {
    $HoraFix = "{0}-{1}-20{2} {3}:{4}:{5} UTC" -f `
        $Campos[9].Substring(0,2), $Campos[9].Substring(2,2), $Campos[9].Substring(4,2),
        $Campos[1].Substring(0,2), $Campos[1].Substring(2,2), $Campos[1].Substring(4,2)
}

try {
    $Lat = Convert-NmeaCoordinate $Campos[3] $Campos[4]
    $Lon = Convert-NmeaCoordinate $Campos[5] $Campos[6]
}
catch {
    Write-Host "Erro ao converter coordenadas: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# IMPORTANTE:
# Forca ponto decimal mesmo em Windows PT-PT.
$LatText = $Lat.ToString(
    "0.######",
    [System.Globalization.CultureInfo]::InvariantCulture
)

$LonText = $Lon.ToString(
    "0.######",
    [System.Globalization.CultureInfo]::InvariantCulture
)

$Url = "https://www.google.com/maps?q=$LatText,$LonText"

# ============================================================
# HTML INTERMEDIARIO
# PowerShell -> Explorer -> Edge/default HTML handler -> Maps
# ============================================================

# Cria o HTML na mesma pasta onde está este .ps1
$HtmlDir = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($HtmlDir)) {
    $HtmlDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$HtmlPath = Join-Path $HtmlDir "GPSLocator.html"

# Codifica caracteres especiais para uso seguro dentro do HTML.
$HtmlUrl = [System.Net.WebUtility]::HtmlEncode($Url)

$Html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>GPS Locator</title>

    <meta http-equiv="refresh" content="0;url=$HtmlUrl">

    <script>
        window.location.replace("$Url");
    </script>
</head>

<body>
    <p>A abrir Google Maps...</p>
    <p><a href="$HtmlUrl">Abrir Google Maps</a></p>
</body>
</html>
"@

Set-Content -LiteralPath $HtmlPath -Value $Html -Encoding UTF8 -Force

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host " GOOGLE MAPS" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host "Latitude : $LatText" -ForegroundColor Cyan
Write-Host "Longitude: $LonText" -ForegroundColor Cyan
Write-Host "Fix      : $HoraFix" -ForegroundColor Cyan
Write-Host $Url -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "HTML: $HtmlPath" -ForegroundColor DarkGray


# Fluxo pretendido:
# explorer.exe -> associacao .html -> browser predefinido -> URL Google Maps
try {
    Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList "`"$HtmlPath`""
    Write-Host "Aberto no browser predefinido." -ForegroundColor Green
}
catch {
    Write-Host "Erro ao abrir o HTML com Explorer: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

exit 0
