param(
    [string]$machine
)

$Log = "\\$machine\c$\GPS\logs\gps-extractor.LOG"

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

$Linha = Get-Content $Log -Tail 10 |
         Where-Object { $_ -match '\$GPRMC,' } |
         Select-Object -First 1

if (-not $Linha) {
    Write-Host "Nenhuma linha GPRMC encontrada nas ultimas 10 linhas." -ForegroundColor Red
    exit 1
}

$RMC = ($Linha -split '\$GPRMC,')[1]
$Campos = ('$GPRMC,' + $RMC).Split(',')

if ($Campos.Count -lt 7) {
    Write-Host "Linha GPRMC invalida." -ForegroundColor Red
    exit 1
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
Write-Host $Url -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "HTML: $HtmlPath" -ForegroundColor DarkGray


# Fluxo pretendido:
# explorer.exe -> associacao .html -> Edge -> URL Google Maps
try {
    Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList "`"$HtmlPath`""
	Write-Host "Aberto com o EDGE" -ForegroundColor Green
}
catch {
    Write-Host "Erro ao abrir o HTML com Explorer: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

exit 0
