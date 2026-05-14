<#
.SYNOPSIS
  Demonstrates PowerShell best practice: Try/Catch/Finally with -ErrorAction Stop
  Processes a file safely with proper error handling.
#>
param(
    [Parameter(Mandatory)]
    [string]$FilePath
)

$ErrorActionPreference = 'Stop'

function Get-FileContentSafely {
    param([string]$Path)
    
    try {
        $content = Get-Content -Path $Path -ErrorAction Stop
        Write-Host "Successfully read $($content.Count) lines from $Path"
        return $content
    }
    catch [System.IO.FileNotFoundException] {
        Write-Error "File not found: $Path"
        return $null
    }
    catch [System.UnauthorizedAccessException] {
        Write-Error "Access denied: $Path"
        return $null
    }
    catch {
        Write-Error "Unexpected error: $_"
        return $null
    }
    finally {
        $ErrorActionPreference = 'Continue'
        Write-Verbose "Cleanup complete" -Verbose
    }
}

$data = Get-FileContentSafely -Path $FilePath
if ($data) {
    $data | Select-Object -First 5
}
