
# Get-NSE12.ps1
# Download the latest 12 available NSE CM-UDiFF bhavcopies
# Package them into one ZIP for Google Colab

# powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-NSE12-v0.ps1

Add-Type -AssemblyName System.IO.Compression.FileSystem

# Configuration
$target = 12
$maxAttempts = 30
$folder = Join-Path $env:USERPROFILE "Downloads\NSE"

# Create a fresh working directory
$work = Join-Path $folder "NSE12_Work"

New-Item -ItemType Directory -Force -Path $work | Out-Null

# Remove files left over from previous runs
Get-ChildItem -Path $work -File | Remove-Item -Force

$date = Get-Date
$count = 0
$attempts = 0
$latestDate = $null

while ($count -lt $target -and $attempts -lt $maxAttempts) {

    $attempts++

    # Skip weekends
    if ($date.DayOfWeek -in @("Saturday", "Sunday")) {
        $date = $date.AddDays(-1)
        continue
    }

    $d = $date.ToString("yyyyMMdd")
    $file = "BhavCopy_NSE_CM_0_0_0_${d}_F_0000.csv.zip"
    $url = "https://nsearchives.nseindia.com/content/cm/$file"
    $path = Join-Path $work $file

    Write-Host "Trying $d ..."

    try {
        Invoke-WebRequest `
            -Uri $url `
            -OutFile $path `
            -TimeoutSec 40 `
            -ErrorAction Stop

        # Validate ZIP integrity
        $zip = [System.IO.Compression.ZipFile]::OpenRead($path)

        try {
            if ($zip.Entries.Count -eq 0) {
                throw "Empty ZIP archive"
            }

            foreach ($entry in $zip.Entries) {
                $stream = $entry.Open()
                try {
                    $buffer = New-Object byte[] 65536
                    while ($stream.Read($buffer, 0, $buffer.Length) -gt 0) {
                        # Read all bytes to detect corruption
                    }
                }
                finally {
                    $stream.Dispose()
                }
            }
        }
        finally {
            $zip.Dispose()
        }

        if ($null -eq $latestDate) {
            $latestDate = $d
        }

        $count++
        Write-Host "  Downloaded ($count/$target)"
    }
    catch {
        Write-Host "  Not available or invalid: $($_.Exception.Message)"
        Remove-Item $path -Force -ErrorAction SilentlyContinue
    }

    $date = $date.AddDays(-1)
}

# Require all 12 files
if ($count -ne $target) {
    throw "Only $count valid bhavcopies downloaded; expected $target."
}

# Create combined ZIP
#$output = Join-Path $folder "NSE12_${latestDate}.zip"
$output = Join-Path $folder "NSE12_${latestDate}_Input-Bhavcopy.zip"

if (Test-Path $output) {
    Remove-Item $output -Force
}

Compress-Archive `
    -Path (Join-Path $work "*.zip") `
    -DestinationPath $output `
    -CompressionLevel Optimal

Write-Host ""
Write-Host "SUCCESS: $count NSE bhavcopies downloaded."
Write-Host "Combined ZIP: $output"
Write-Host "Size: $([math]::Round((Get-Item $output).Length / 1MB, 2)) MB"
