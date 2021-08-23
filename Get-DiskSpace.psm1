# Documentation home: https://github.com/engrit-illinois/Get-DiskSpace

function Get-DiskSpace {
	
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[string[]]$ComputerName,
		
		[string]$OUDN = "OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu",
		
		[string]$Disk = "C:",
		
		[int]$PercentGood = 50,
		[int]$PercentLow = 25,
		[int]$PercentCritical = 10,
		
		[switch]$MakeLog,
		[switch]$MakeCsv,
		[string]$LogDir = "c:\engrit\logs"
	)
	
	$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
	$LOG = "$LogDir\Get-DiskSpace_$ts.log"
	$CSV = "$LogDir\Get-DiskSpace_$ts.csv"
	
	function log {
		param(
			[string]$Msg,
			[switch]$ToCsv,
			[switch]$LogOnly
		)
		
		if(!$LogOnly) {
			Write-Host $Msg
		}
		
		if($MakeLog) {
			if(!(Test-Path -PathType Leaf -Path $LOG)) {
				$shutup = New-Item -ItemType File -Force -Path $LOG
			}
			$Msg | Out-File $LOG -Append
		}
		
		if($ToCsv) {
			if($MakeCsv) {
				if(!(Test-Path -PathType Leaf -Path $CSV)) {
					$shutup = New-Item -ItemType File -Force -Path $CSV
				}
				$Msg | Out-File $CSV -Append -Encoding Ascii
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
		log "Name,Disk size (GB),Free space (GB),Free space (%)" -ToCsv
		
		$data = @()
		foreach($comp in $comps) {
			$size = "unknown"
			$free = "unknown"
			$perc = "unknown"
			$this = $null
			try {
				$this = Get-CimInstance -ClassName "Win32_LogicalDisk" -ComputerName $comp -Filter "DeviceID='$Disk'" -ErrorAction SilentlyContinue | Select-Object Size,FreeSpace
			}
			catch {
			}
			
			if($this) {
				$size = [math]::Round($this.Size/1GB,2)
				$free = [math]::Round($this.FreeSpace/1GB,2)
				$perc = [int]([math]::Round($free/$size,2)*100)
			}
			
			log "$comp,$size,$free,$perc" -ToCsv
			
			$data += [ordered]@{
				"Name" = $comp
				"Disk size (GB)" = $size
				"Free space (GB)" = $free
				"Free space (%)" = $perc
			}
		}
		$data
	}
	
	function Print-Data($data) {
		
		# Output regular table to log
		$table = $data | foreach {[PSCustomObject]$_} | Format-Table -AutoSize "Name","Disk size (GB)","Free space (GB)","Free space (%)"
		log ($table | Out-String) -LogOnly
		
		# Print table with color coding to console
		$e = [char]27 # escape char
		$table = $data | foreach {[PSCustomObject]$_} | Format-Table -AutoSize "Name","Disk size (GB)","Free space (GB)",@{
			Label = "Free space (%)"
			Align = "Right"
			Expression = {
				$size = $_."Disk size (GB)"
				$free = $_."Free space (GB)"
				$perc = $_."Free space (%)"
				$color = 0
				# https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#text-formatting
				if($perc -le $PercentGood) { $color = "93" } # yellow fg
				if($perc -le $PercentLow) { $color = "91" } # red fg
				if($perc -le $PercentCritical) { $color = "101" } # red bg
			   "$e[${color}m$($perc)${e}[0m"
			}
		}
		$table
		
	}
	
	log " "
	
	$comps = Get-Comps
	$data = Get-Data $comps
	log " "
	Print-Data $data
	log " " -LogOnly
	log "EOF"
	log " "
}