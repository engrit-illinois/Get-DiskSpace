# Documentation home: https://github.com/engrit-illinois/Get-DiskSpace

function Get-DiskSpace {
	
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[string[]]$ComputerName,
		
		[string]$OUDN = "OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu",
		
		[string]$Disk = "C:",
		
		[switch]$Parallel,
		[int]$ThrottleLimit = 50,
		
		[int]$PercentGood = 50,
		[int]$PercentLow = 25,
		[int]$PercentCritical = 10,
		
		[switch]$Loud,
		[switch]$MakeLog,
		[switch]$MakeCsv,
		[string]$LogDir = "c:\engrit\logs",
		
		[switch]$PassThru
	)
	
	$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
	$LOG = "$LogDir\Get-DiskSpace_$ts.log"
	$CSV = "$LogDir\Get-DiskSpace_$ts.csv"
	
	function log {
		param(
			[string]$Msg,
			[switch]$ToCsv,
			[switch]$LogOnly,
			[switch]$NoLog,
			[switch]$ForceLogConsole,
			[switch]$FromParallel,
			[int]$L = 0
		)
		
		$originalMsg = $Msg
		for($i = 0; $i -lt $L; $i += 1) {
			$Msg = "    $Msg"
		}
		
		if(($Loud -and (-not $LogOnly)) -or $ForceLogConsole) {
			Write-Host $Msg
		}
		
		if($MakeLog -and (-not $NoLog)) {
			if(-not ($Parallel -and $FromParallel)) {
				if(!(Test-Path -PathType Leaf -Path $LOG)) {
					$shutup = New-Item -ItemType File -Force -Path $LOG
				}
				$Msg | Out-File $LOG -Append
			}
		}
	}

	function Get-Comps {
		$comps = @()
		foreach($query in @($ComputerName)) {
			$thisQueryComps = (Get-ADComputer -Filter "name -like '$query'" -SearchBase $OUDN | Select Name).Name
			$comps += @($thisQueryComps)
		}
		$comps
	}
	
	function Get-Data($comps) {
		log "Polling computers..."
		if($Parallel) {
			log "Note: logging for individual computers is disabled when -Parallel is specified." -L 1
		}
		
		$scriptblock = {
			try {
				$LOG = $using:LOG
				$CSV = $using:CSV
				$Loud = $using:Loud
				$Disk = $using:Disk
				${function:log} = $using:logFunction
			}
			catch {}
			
			$comp = $_
			
			log "Name: $($comp), Action: Polling..." -L 1 -FromParallel
			
			$size = $null
			$free = $null
			$perc = $null
			$diskInfo = $null
			$err = $null
			
			try {
				$diskInfo = Get-CimInstance -ClassName "Win32_LogicalDisk" -ComputerName $comp -Filter "DeviceID='$Disk'" -ErrorAction "Stop" | Select-Object Size,FreeSpace
			}
			catch {
				$err = $_.Exception.Message
				log "Name: $($comp), Error: $err" -L 1 -FromParallel
			}
			
			log "Name: $($comp), Action: Done polling." -L 1 -FromParallel
			
			if($diskInfo) {
				$size = [math]::Round($diskInfo.Size/1GB,2)
				$free = [math]::Round($diskInfo.FreeSpace/1GB,2)
				$perc = [math]::Round((($free/$size)*100),2)
			}
			
			$data = [PSCustomObject][ordered]@{
				"Name" = $comp
				"Disk size (GB)" = $size
				"Free space (GB)" = $free
				"Free space (%)" = $perc
				"Error" = $err
			}
			
			log "Name: $($comp), Results: (Size: $($data."Disk size (GB)"), Size: $($data."Free space (GB)"), Size: $($data."Free space (%)"), Error: $($data.Error))" -L 1 -FromParallel
			
			$data
		}
				
		if($Parallel) {
			$logFunction = ${function:log}.ToString()
			$data = $comps | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel $scriptblock
		}
		else {
			$data = $comps | ForEach-Object $scriptblock
		}
		
		log "Done polling computers."
		
		$data | Sort Name
	}
	
	function Log-Data($data) {
		if($MakeLog) {
			$table = $data | Format-Table -AutoSize
			log ($table | Out-String) -LogOnly
		}
	}
	
	function Export-Data($data) {
		if($MakeCsv) {
			$data | Export-Csv $CSV -Encoding "Ascii" -NoTypeInformation
		}
	}
	
	function Return-Data($data) {
		if(-not $PassThru) {
			$e = [char]27 # escape char
			$table = $data | Format-Table -AutoSize `
				"Name",
				@{
					Name = "Disk size (GB)"
					Align = "Right"
					Expression = { $_."Disk size (GB)".ToString("0.00")}
				},
				@{
					Name = "Free space (GB)"
					Align = "Right"
					Expression = { $_."Free space (GB)".ToString("0.00")}
				},
				@{
					Name = "Free space (%)"
					Align = "Right"
					Expression = {
						$size = $_."Disk size (GB)"
						$free = $_."Free space (GB)"
						$perc = $_."Free space (%)"
						$percString = $perc.ToString("0.00")
						$color = 0
						# https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#text-formatting
						if($perc -le $PercentGood) { $color = "93" } # yellow fg
						if($perc -le $PercentLow) { $color = "91" } # red fg
						if($perc -le $PercentCritical) { $color = "101" } # red bg
					   "$e[${color}m$($percString)${e}[0m"
					}
				},
				"Error"
			$table
		}
		else {
			$data
		}
	}
	
	function Validate-PsVersion {
		log "Validating PowerShell version..."
		
		$ver = $Host.Version
		log "Powershell version is `"$($ver.Major).$($ver.Minor)`"." -L 1
		
		if($Parallel) {
			if($ver.Major -lt 7) {
				log "-Parallel is only supported in PowerShell 7+!" -L 1 -ForceLogConsole
				return $false
			}
		}
		return $true
	}

	
	function Do-Stuff {
		if(Validate-PsVersion) {
			$comps = Get-Comps
			$data = Get-Data $comps
			Log-Data $data
			Export-Data $data
			Return-Data $data
		}
	}
	
	Do-Stuff
	
	log "EOF"
}