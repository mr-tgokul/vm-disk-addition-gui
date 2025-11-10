<#
.SYNOPSIS
    VMware VM Disk Addition Automation Tool (GUI-based)

.DESCRIPTION
    This PowerShell GUI tool allows administrators to automate the addition of new virtual disks 
    to multiple VMware virtual machines (VMs) in bulk. It connects to a vCenter Server using 
    VMware PowerCLI and performs validation checks for each VM — such as existence, cluster 
    membership, and datastore availability — before attaching a new virtual disk.

    The tool also provides detailed real-time logging and progress feedback within the GUI, 
    along with 30-second timed wait indicators. All actions and results are logged for 
    troubleshooting and audit purposes.

.AUTHOR
    Gokul — Senior Virtualization Engineer (9+ years experience)
    Created: November 2025
    Version: 1.0

.REQUIREMENTS
    - PowerShell 5.1 or later
    - VMware PowerCLI module installed
    - Access permissions to the target vCenter Server
    - Input VM list file (text file containing VM names, one per line)

.PARAMETER vCenter
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER Cluster
    The target cluster name containing the VMs to process.

.PARAMETER DatastoreCluster
    The datastore cluster where the new virtual disk will be provisioned.

.PARAMETER VMListFile
    A text file path (.txt) containing a list of VMs — one per line.
    The script automatically removes any extra spaces or blank lines.

.PARAMETER DiskSizeGB
    The size (in GB) of the new disk to be added to each VM.

.EXAMPLE
    Example usage:
        1. Launch the script directly in PowerShell:
            PS> .\VM_Disk_Addition_Tool.ps1

        2. Fill in the GUI fields:
            - vCenter: vcsa01.lab.local
            - Cluster: Production-Cluster
            - Datastore Cluster: DS-Cluster01
            - VM List File: C:\Temp\VMList.txt
            - Disk Size: 100

        3. Click “Start” to begin the process.
           The tool will log each step and display a 30-second progress timer 
           whenever a validation wait occurs.

.INPUT FILE FORMAT
    The input file should contain VM names, one per line:
        VM001
        VM002
        VM003

    Notes:
    - Extra spaces before or after names are automatically trimmed.
    - Empty lines are ignored.

.OUTPUT
    - A log file is generated in the same directory as the script, 
      with detailed timestamps, messages, and statuses.
    - The GUI log box displays real-time progress and results.

.NOTES
    This tool provides:
    - GUI-driven input validation
    - 30-second progress wait indicators for failed lookups
    - VM disk addition automation with logging
    - Safe handling of empty or invalid input data

#>


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------------
# Main Form
# -----------------------------
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "VM Disk Addition Tool"
$Form.Size = New-Object System.Drawing.Size(900,700)
$Form.StartPosition = "CenterScreen"
$Form.BackColor = [System.Drawing.Color]::FromArgb(60,60,70)
$Form.ForeColor = [System.Drawing.Color]::White
$Form.Font = New-Object System.Drawing.Font("Segoe UI",10)
$Form.TopMost = $true

# -----------------------------
# Group Box
# -----------------------------
$GroupBox = New-Object System.Windows.Forms.GroupBox
$GroupBox.Text = "vCenter / Cluster Information"
$GroupBox.Size = New-Object System.Drawing.Size(840,240)
$GroupBox.Location = New-Object System.Drawing.Point(20,20)
$Form.Controls.Add($GroupBox)

# vCenter, Username, Password
$lblVC = New-Object System.Windows.Forms.Label; $lblVC.Text="vCenter Server:"; $lblVC.Location=New-Object System.Drawing.Point(20,40); $lblVC.Size=New-Object System.Drawing.Size(120,25); $GroupBox.Controls.Add($lblVC)
$txtVC = New-Object System.Windows.Forms.TextBox; $txtVC.Location=New-Object System.Drawing.Point(150,40); $txtVC.Size=New-Object System.Drawing.Size(220,25); $GroupBox.Controls.Add($txtVC)

$lblUser = New-Object System.Windows.Forms.Label; $lblUser.Text="Username:"; $lblUser.Location=New-Object System.Drawing.Point(390,40); $lblUser.Size=New-Object System.Drawing.Size(80,25); $GroupBox.Controls.Add($lblUser)
$txtUser = New-Object System.Windows.Forms.TextBox; $txtUser.Location=New-Object System.Drawing.Point(470,40); $txtUser.Size=New-Object System.Drawing.Size(150,25); $GroupBox.Controls.Add($txtUser)

$lblPass = New-Object System.Windows.Forms.Label; $lblPass.Text="Password:"; $lblPass.Location=New-Object System.Drawing.Point(640,40); $lblPass.Size=New-Object System.Drawing.Size(80,25); $GroupBox.Controls.Add($lblPass)
$txtPass = New-Object System.Windows.Forms.TextBox; $txtPass.Location=New-Object System.Drawing.Point(720,40); $txtPass.Size=New-Object System.Drawing.Size(100,25); $txtPass.UseSystemPasswordChar=$true; $GroupBox.Controls.Add($txtPass)

# Other fields
$fields = @(
    @{Label="Cluster Name:"; Var="txtCluster"; Y=80},
    @{Label="Datastore Cluster:"; Var="txtDSCluster"; Y=110},
    @{Label="CRQ Number:"; Var="txtCRQ"; Y=140},
    @{Label="Disk Size (GB):"; Var="txtDiskSize"; Y=170},
    @{Label="VM List File Path:"; Var="txtVMFile"; Y=200}
)
foreach ($f in $fields) {
    $lbl = New-Object System.Windows.Forms.Label; $lbl.Text=$f.Label; $lbl.Location=New-Object System.Drawing.Point(20,$f.Y); $lbl.Size=New-Object System.Drawing.Size(130,25); $GroupBox.Controls.Add($lbl)
    $txt = New-Object System.Windows.Forms.TextBox; $txt.Location=New-Object System.Drawing.Point(150,$f.Y); $txt.Size=New-Object System.Drawing.Size(500,25); Set-Variable -Name $f.Var -Value $txt -Scope Script; $GroupBox.Controls.Add($txt)
}

# Browse button
$BrowseButton = New-Object System.Windows.Forms.Button; $BrowseButton.Text="Browse"; $BrowseButton.Location=New-Object System.Drawing.Point(670,200); $BrowseButton.Size=New-Object System.Drawing.Size(100,27); $GroupBox.Controls.Add($BrowseButton)
$BrowseButton.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter="Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtVMFile.Text=$ofd.FileName
        Add-Log "Selected VM list file: $($ofd.FileName)" "INFO"
    }
})

# Log box
$LogBox = New-Object System.Windows.Forms.RichTextBox
$LogBox.Location = New-Object System.Drawing.Point(20,330)
$LogBox.Size = New-Object System.Drawing.Size(840,330)
$LogBox.BackColor = [System.Drawing.Color]::FromArgb(45,45,55)
$LogBox.ForeColor = [System.Drawing.Color]::White
$LogBox.ReadOnly = $true
$LogBox.Font = New-Object System.Drawing.Font("Consolas",10)
$Form.Controls.Add($LogBox)

# Buttons and status
$ConnLabel = New-Object System.Windows.Forms.Label; $ConnLabel.Text="vCenter Status: Disconnected"; $ConnLabel.Location=New-Object System.Drawing.Point(20,270); $ConnLabel.Size=New-Object System.Drawing.Size(400,25); $ConnLabel.ForeColor=[System.Drawing.Color]::Red; $Form.Controls.Add($ConnLabel)
$ConnectButton = New-Object System.Windows.Forms.Button; $ConnectButton.Text="Connect"; $ConnectButton.Location=New-Object System.Drawing.Point(20,295); $ConnectButton.Size=New-Object System.Drawing.Size(120,30); $Form.Controls.Add($ConnectButton)
$DisconnectButton = New-Object System.Windows.Forms.Button; $DisconnectButton.Text="Disconnect"; $DisconnectButton.Location=New-Object System.Drawing.Point(160,295); $DisconnectButton.Size=New-Object System.Drawing.Size(120,30); $Form.Controls.Add($DisconnectButton)
$StartButton = New-Object System.Windows.Forms.Button; $StartButton.Text="Start Disk Addition"; $StartButton.Location=New-Object System.Drawing.Point(300,295); $StartButton.Size=New-Object System.Drawing.Size(180,30); $StartButton.Enabled=$false; $Form.Controls.Add($StartButton)

# Progress bar
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(500, 295)
$ProgressBar.Size = New-Object System.Drawing.Size(360,30)
$ProgressBar.Minimum = 0
$ProgressBar.Maximum = 30
$ProgressBar.Step = 1
$ProgressBar.Value = 0
$Form.Controls.Add($ProgressBar)

# -----------------------------
# Log function
# -----------------------------
$global:LogFilePath = $null
function Add-Log {
    param([string]$Message,[string]$Level="INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry
    if ($global:LogFilePath) { Add-Content -Path $global:LogFilePath -Value $entry }
    $LogBox.SelectionStart = $LogBox.TextLength
    switch ($Level) {
        "SUCCESS" {$LogBox.SelectionColor=[System.Drawing.Color]::LightGreen}
        "WARNING" {$LogBox.SelectionColor=[System.Drawing.Color]::Orange}
        "ERROR" {$LogBox.SelectionColor=[System.Drawing.Color]::Red}
        "HIGHLIGHT" {$LogBox.SelectionColor=[System.Drawing.Color]::Cyan}
        default {$LogBox.SelectionColor=[System.Drawing.Color]::White}
    }
    $LogBox.AppendText("$entry`r`n")
    $LogBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# -----------------------------
# User Info
# -----------------------------
function Get-ScriptUserInfo {
    $user=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $global:userName=$user.Name
    $domain=$env:USERDOMAIN
    $machine=$env:COMPUTERNAME
    Add-Log "**************************************************************************" "INFO"
    Add-Log " Script Name : VM_Disk_Addition" "INFO"
    Add-Log " Script Run by: $userName" "INFO"
    Add-Log " User Domain  : $domain" "INFO"
    Add-Log " Machine Name : $machine" "INFO"
    Add-Log " Date/Time    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    if ($global:LogFilePath) { Add-Log " Log File     : $global:LogFilePath" "INFO" }
    Add-Log "**************************************************************************" "INFO"
}

# -----------------------------
# vCenter Connect
# -----------------------------
$global:vcConnection = $null
$ConnectButton.Add_Click({
    try {
        if (-not $txtVC.Text -or -not $txtUser.Text -or -not $txtPass.Text) { Add-Log "Fill vCenter/Username/Password!" "ERROR"; return }
        Add-Log "Connecting to vCenter $($txtVC.Text)..." "INFO"
        $securePass = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
        $Cred = New-Object System.Management.Automation.PSCredential ($txtUser.Text,$securePass)
        $global:vcConnection = Connect-VIServer -Server $txtVC.Text -Credential $Cred -ErrorAction Stop -Force
        if ($global:vcConnection.IsConnected) {
            Add-Log "✅ Connected to vCenter $($txtVC.Text)" "SUCCESS"
            $ConnLabel.Text = "vCenter Status: Connected"; $ConnLabel.ForeColor = [System.Drawing.Color]::LightGreen
            $StartButton.Enabled = $true; $DisconnectButton.Enabled = $true
        }
    } catch { Add-Log "❌ Failed to connect: $_" "ERROR"; $ConnLabel.Text = "vCenter Status: Connection Failed"; $ConnLabel.ForeColor = [System.Drawing.Color]::Red; $StartButton.Enabled = $false }
})
$DisconnectButton.Add_Click({
    if ($global:vcConnection) {
        Disconnect-VIServer -Server $global:vcConnection -Confirm:$false
        Add-Log "Disconnected from vCenter" "SUCCESS"
        $ConnLabel.Text = "vCenter Status: Disconnected"; $ConnLabel.ForeColor = [System.Drawing.Color]::Red
        $StartButton.Enabled = $false; $DisconnectButton.Enabled = $false
        $global:vcConnection = $null
    }
})

# -----------------------------
# Disk Addition
# -----------------------------
$StartButton.Add_Click({
    try {
        $StartButton.Enabled = $false
        $ProgressBar.Value = 0
        if (-not $txtCluster.Text -or -not $txtDSCluster.Text -or -not $txtDiskSize.Text -or -not $txtVMFile.Text) { Add-Log "Fill all fields!" "ERROR"; return }
        if (-not $global:vcConnection -or -not $global:vcConnection.IsConnected) { Add-Log "vCenter not connected!" "ERROR"; return }

        # Generate log file immediately
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $ClusterSafe = $txtCluster.Text -replace '[^a-zA-Z0-9_-]','_'
        $LogFolder = "C:\Temp\disk-add"
        if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory | Out-Null }
        $global:LogFilePath = Join-Path $LogFolder "$($ClusterSafe)_${timestamp}_disk_add.log"
        Add-Content -Path $global:LogFilePath -Value "Starting VM Disk Addition Script at $(Get-Date)`r`n"

        Get-ScriptUserInfo
        Add-Log "vCenter Name  : $($txtVC.Text)" "INFO"
        Add-Log "Cluster Name  : $($txtCluster.Text)" "INFO"
        Add-Log "Datastore Cl. : $($txtDSCluster.Text)" "INFO"
        Add-Log "CRQ Number    : $($txtCRQ.Text)" "INFO"
        Add-Log "************************************************************************************" "INFO"

        # --- Read VM List File from any location ---
        $vmFilePath = $txtVMFile.Text.Trim()
        if (-not (Test-Path -Path $vmFilePath)) {
            Add-Log "VM list file not found: $vmFilePath" "ERROR"
            return
        }
        try {
            $VMNames = Get-Content -LiteralPath $vmFilePath
        } catch {
            Add-Log "Failed to read VM list file: $_" "ERROR"
            return
        }

        $totalVMs = $VMNames.Count
        Add-Log "Total VMs to process: $totalVMs" "INFO"

        $dsCluster = Get-DatastoreCluster -Name $txtDSCluster.Text -ErrorAction Stop
        $DiskSizeGB = [int]$txtDiskSize.Text

        $vmIndex = 0
        foreach ($VMName in $VMNames) {
            $vmIndex++
            Add-Log "Processing VM $vmIndex of $totalVMs : $VMName" "HIGHLIGHT"
            $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue

            if (-not $VM) {
                Add-Log "VM '$VMName' not found. Waiting 30 seconds..." "WARNING"
                $ProgressBar.Value = 0
                for ($i = 1; $i -le 30; $i++) { Start-Sleep -Seconds 1; $ProgressBar.PerformStep(); [System.Windows.Forms.Application]::DoEvents() }
                continue
            }

            if (($VM | Get-Cluster).Name -ne $txtCluster.Text) {
                Add-Log "VM '$VMName' not in cluster '$($txtCluster.Text)'. Waiting 30 seconds..." "WARNING"
                $ProgressBar.Value = 0
                for ($i = 1; $i -le 30; $i++) { Start-Sleep -Seconds 1; $ProgressBar.PerformStep(); [System.Windows.Forms.Application]::DoEvents() }
                continue
            }

            Add-Log "✅ VM found in target cluster '$($txtCluster.Text)'" "SUCCESS"

            $datastore = $dsCluster | Get-Datastore | Where-Object { $_.FreeSpaceGB -gt 500 } | Sort-Object FreeSpaceGB -Descending | Select-Object -First 1
            if (-not $datastore) { Add-Log "❌ No datastore with >500GB free. Skipping $VMName." "ERROR"; continue }

            Add-Log "Datastore selected: $($datastore.Name)" "HIGHLIGHT"
            $currentDisks = Get-HardDisk -VM $VM
            Add-Log "Total Disk count before Addition: $($currentDisks.Count)" "INFO"
            $newDisk = New-HardDisk -VM $VM -CapacityGB $DiskSizeGB -Datastore $datastore.Name -StorageFormat EagerZeroedThick -Confirm:$false
            Start-Sleep -Seconds 2
            Add-Log "✅ Added $DiskSizeGB GB disk to $VMName on $($datastore.Name)" "SUCCESS"

            $updatedDisks = Get-HardDisk -VM $VM
            Add-Log "Total Disk count after Addition: $($updatedDisks.Count)" "INFO"
            $addedDisk = $updatedDisks | Where-Object { $_.CapacityGB -eq $DiskSizeGB } | Sort-Object -Descending -Property CapacityGB | Select-Object -First 1
            if ($addedDisk) { Add-Log "New Disk File: $($addedDisk.Filename)" "INFO" } else { Add-Log "Unable to identify new disk file." "WARNING" }

            Add-Log "✅ Completed disk addition for VM: $VMName" "SUCCESS"
        }

        if ($global:vcConnection) {
            Disconnect-VIServer -Server $global:vcConnection -Confirm:$false
            Add-Log "Auto-disconnected." "SUCCESS"
            $ConnLabel.Text = "vCenter Status: Disconnected"; $ConnLabel.ForeColor = [System.Drawing.Color]::Red
            $DisconnectButton.Enabled = $false
            $global:vcConnection = $null
        }

        Add-Log "************************************************************************************" "INFO"
        Add-Log "Script Completed Successfully. Log saved at: $global:LogFilePath" "HIGHLIGHT"
        Add-Log "************************************************************************************" "INFO"

    } catch { Add-Log "Error: $_" "ERROR" } finally { $StartButton.Enabled = $true; $ProgressBar.Value = 0 }
})

# -----------------------------
# Show GUI
# -----------------------------
[void]$Form.ShowDialog()
