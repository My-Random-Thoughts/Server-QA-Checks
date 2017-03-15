Function Process-Start ([string]$FilePath, [string]$Arguments)
{
    Try
    {
        $Info    = New-Object System.Diagnostics.ProcessStartInfo
        $Process = New-Object System.Diagnostics.Process

        $Info.FileName               = $FilePath
        $Info.RedirectStandardError  = $true
        $Info.RedirectStandardOutput = $true
        $Info.UseShellExecute        = $false
        $Info.Arguments              = $Arguments

        $Process.StartInfo = $Info
        $Process.Start() | Out-Null
        [string]$stdOut = $Process.StandardOutput.ReadToEnd()
        [string]$stdErr = $Process.StandardError.ReadToEnd()
        $Process.WaitForExit(10000)    # Wait maximum of 10 seconds

        If  ($process.ExitCode -eq 0) { Return ($stdOut.Split("`n")) }    # Standard Output
        Else {
            If ($stdErr.Length -gt 0) { Return ($stdErr.Split("`n")) }    # Standard Error  (if it exists)
            Else                      { Return ($stdOut.Split("`n")) }    # Standard Output (if there are no errors)
        }
    }
    Catch { Return "ERROR: $($_.Exception.Message)" }
}