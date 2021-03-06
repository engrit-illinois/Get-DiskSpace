# Summary
This script reports the disk size and free space from a list of remote computers.
It calculates percent free space, and outputs the data in a convenient table to the screen, highlighting entries with low disk space. It also optionally outputs a log and a CSV file of the data.  
Intended just for a fast glance at disk space health of multiple machines. It's very fast, except when it tries to contact machines which don't respond.

# Usage
- Download `Get-DiskSpace.psm1`
- Import it as a module: `Import-Module "c:\path\to\script\Get-DiskSpace.psm1"`
- Run it using the examples and parameter documentation below.

# Examples
- `Get-DiskSpace "espl-114-01"`
- `Get-DiskSpace "espl-114-01","espl-114-02","tb-207-01"`
- `Get-DiskSpace "espl-114-*"`
- `Get-DiskSpace "espl-114-*","tb-207-01","tb-306-*"`

# Example output:
```powershell
C:\>Get-DiskSpace "espl-114-*"

Name        Disk size (GB) Free space (GB) Free space (%)
----        -------------- --------------- --------------
ESPL-114-01            931            27.1              3
ESPL-114-02            931          480.07             52
ESPL-114-03            931          574.95             62
ESPL-114-04         931.51          430.59             46
ESPL-114-05            931          603.33             65
ESPL-114-06            931          408.35             44
ESPL-114-07            931          535.12             57
ESPL-114-08            931          455.22             49
ESPL-114-09        unknown         unknown        unknown

C:\>
```

<img src='Get-DiskSpace_example-output.png' />

# Parameters

### -ComputerName [string[]]
Required string array.  
The list of computer names and/or computer name query strings to poll for disk space data.  
Use an asterisk (`*`) as a wildcard.  
The parameter name may be omitted if the value is given as the first or only parameter.  

### -Disk [string]
Optional string.  
The local disk abotu which to gather data.  
Default is `"C:"`.  

### -OUDN [string]
Optional string.  
The OU distinguished name of the OU to limit the computername search to.  
Default is `"OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`.  

### -MakeLog
Optional switch.  
Whether or not to log output to a log file.  
Log filename will be `Get-DiskSpace_yyyy-MM-dd_HH-mm-ss.log`.  
Log will be created in the directory specified by the `-LogDir` parameter.  

### -MakeCsv
Optional switch.  
Whether or not to log retrieved data to a CSV file.  
CSV filename will be `Get-DiskSpace_yyyy-MM-dd_HH-mm-ss.csv`.  
CSV will be created in the directory specified by the `-LogDir` parameter.  

### -LogDir [string]
Optional string.  
The directory in which to create log and/or CSV files, if any are created.  
Default is `"c:\engrit\logs"`.  

### -PercentGood [int]
Optional integer.  
The `Free space (%)` value printed in the console output for computers with a value > `-PercentGood` will be uncolored.  
Default is `50`.

### -PercentLow [int]
Optional integer.  
The `Free space (%)` value printed in the console output for computers with a value <= `-PercentGood` and > `-PercentLow` will be colored with a yellow foreground.  
Default is `25`.  

### -PercentCritical [int]
Optional integer.  
The `Free space (%)` value printed in the console output for computers with a value <= `-PercentLow` and > `-PercentCritical` will be colored with a red foreground.  
The `Free space (%)` value printed in the console output for computers with a value <= `-PercentCritical` will be colored with a red background.  
Default is `10`.    

# Notes
- Data that could not be collected (i.e. for machines that couldn't be contacted, or for which you don't have admin) will show as `unknown`.
- If run in a host that supports color coding (i.e. the default Powershell console), the values in the `Free space (%)` column will be colored according to the "Percent" parameters above. This is useful for quick scanning of results from many computers.
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.
