<# 
.SYNOPSIS 
    Standardise Photo and Video filenames and timestamps.
.DESCRIPTION 
    DateFix.ps1 accepts a folder from the user then works through the files (optionally recursing) to name them as consistently as possible using the yyyyMMdd_HHmmss.ext format.
    
    The scripts first tries to use the embedded Date Taken EXIF Date, if this is not available the file's current filename is used.
.PARAMETER Path
    The root folder to be processed, e.g. C:\Users\Username\Pictures\
.PARAMETER Recurse
    Whether or not to recurse through sub-directories of the root folder.
.PARAMETER Verbose
    Enables verbose output.
.EXAMPLE
    DateFix.ps1
    Get asked for Path and whether to recurse or not.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\
    Process C:\Users\Username\Pictures\ and be asked whether to recurse or not.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\ -Recurse $true
    Recursively Process C:\Users\Username\Pictures\ with minimal output.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\ -Recurse $false
    Process C:\Users\Username\Pictures\ without recursing with minimal output.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\ -Recurse $true -Verbose
    Recursively Process C:\Users\Username\Pictures\ with verbose output.
.NOTES 
    Author  : Joe Pitt
    License : DateFix by Joe Pitt is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
.LINK 
    https://www.joepitt.co.uk/Project/DateFix/
#>
param ([string]$Path, [bool]$Recurse, [switch]$Verbose)


$oldverbose = $VerbosePreference
if($Verbose) 
{
	$VerbosePreference = "continue" 
}

[Reflection.Assembly]::LoadFile('C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Drawing.dll') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

# Get the directory to be processed.
function Get-Directory()
{   
	$FolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog 
	$FolderDialog.Description = "Select Folder to process"
	$FolderDialog.ShowNewFolderButton = $false
	$FolderDialog.ShowDialog() | Out-Null
	$FolderDialog.SelectedPath
}

# Load the iamge and pass it to Get-TakenDate
function Get-EXIFDate
{
	param( [string]$file )
	try 
	{
		$image = New-Object System.Drawing.Bitmap -ArgumentList $file
		$takenData = Get-TakenData($image)
		if ($takenData -eq $null) 
		{
			$image.Dispose()
			return $null
		}
		$takenValue = [System.Text.Encoding]::Default.GetString($takenData, 0, $takenData.Length - 1)
		$taken = [DateTime]::ParseExact($takenValue, 'yyyy:MM:dd HH:mm:ss', $null)
		$image.Dispose()
		return $taken.ToString('yyyyMMdd_HHmmss')
	}
	catch
	{
		return $null
	}
}

# Read the EXIF Taken Date from the provided image.
function Get-TakenData($image) 
{
	try 
	{
		return $image.GetPropertyItem(36867).Value
	}   
	catch 
	{
		return $null
	}
}

# Sets the file's timestamps to the provided datetime.
Function Set-FileTimeStamps
{
	param ( [Parameter(mandatory=$true)] [string[]]$path, [datetime]$date = (Get-Date) )
	Get-ChildItem -Path $path |
	ForEach-Object {
		$_.CreationTime = $date
		$_.LastAccessTime = $date
		$_.LastWriteTime = $date 
   }
}

$origDir = $(Get-Location)
Write-Verbose "Original Location $origDir"

# Get and Test path
if(!$PSBoundParameters.ContainsKey('Path'))
{
    $Path = Get-Directory
}
if (Test-Path "$Path")
{
    Set-Location "$Path"
    Write-Verbose "Using '$Path'"
}
else
{
    Write-Error -Message "Path does not exist." -RecommendedAction "Check path and try again" -ErrorId "1" `
        -Category ObjectNotFound -CategoryActivity "Testing Path Exists" -CategoryReason "The Path was not found" `
        -CategoryTargetName "$Path" -CategoryTargetType "Directory"
    exit 1
}

# Get answer to Recurse
if(!$PSBoundParameters.ContainsKey('Recurse'))
{
    $message = "Process all sub-folders too?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Process all sub-folders."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Process only the selected folder."
    $cancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Do not process any folders."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $cancel)
    $result = $host.ui.PromptForChoice($title, $message, $options, 1)
    switch ($result) 
    {
	    0 { $Recurse = $true }
        1 { $Recurse = $false }
        2 { Set-Location $origDir; Exit 2 }
    }
}

# Get Files
if ($Recurse)
{
    $files = Get-ChildItem -Recurse -File
    Write-Verbose "Recursive Mode Enabled"
}
else
{
	$files = Get-ChildItem -File
}

# Process Files
foreach ($file in $files)
{
	Write-Verbose $file.FullName
	Set-Location $file.DirectoryName
	$NewName = $file.Name.Substring(0, $file.Name.LastIndexOf('.'))
	$ext = $file.Name.Substring($file.Name.LastIndexOf('.'))

    ## Detect DateTime

	# EXIF (Preferred)
	$EXIFDate = Get-EXIFDate $file.FullName
	if ($EXIFDate -ne $null)
	{
		$NewName = $EXIFDate
		Write-Verbose "  Using EXIF Date Taken"
	}
    # Filename Fallback
	else
	{
		Write-Verbose "  EXIF Date Taken not found, trying RegEx"
		switch -Regex ($NewName)
		{
            # Preferred Format yyyyddmm_hhmmss or yyyyddmm_hhmmss-FreeText
            '^[0-9]{8}_[0-9]{6}(-[^/\\?%*:|"<>. ]+)?$'
            {
                Write-Verbose "  Match: yyyyddmm_hhmmss or yyyyddmm_hhmmss-FreeText (Preferred)"
                break
            }

			# yyyyddmm_hhmmss_n
			'^[0-9]{8}_[0-9]{6}_[^/\\?%*:|"<>. ]+$'
			{
				Write-Verbose "  Match: yyyyddmm_hhmmss_n"
                $NewName = $NewName.Substring(0, 15) + "-" + $NewName.Substring(16)
                Write-Verbose "    > $NewName"
                break
			}

			# IMG_yyyymmdd_hhmmss or IMG_yyyymmdd_hhmmss~x
			'^IMG_[0-9]{8}_[0-9]{6}(~[0-9]+)$'
			{
				Write-Verbose "  Match: IMG_yyyymmdd_hhmmss"
                $NewName = $NewName.Substring(4)
                Write-Verbose "    > $NewName"
                break
			}

			# IMG-yyyymmdd-WAnnnn
			'^IMG-[0-9]{8}-WA[0-9]{4}$'
			{
				Write-Verbose "  Match: IMG-yyyymmdd-WAnnnn"
                $NewName = "$($NewName.Substring(4, 8))_000000"
				Write-Verbose "    > $NewName"
                break
			}

			# Photo dd-mm-yyyy hh mm ss
			'^Photo [0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2}$'
			{
				Write-Verbose "  Match: Photo dd-mm-yyyy hh mm ss"
				$NewName = $NewName.Substring(6)
				$NewName = $NewName.Substring(6, 4) + $NewName.Substring(3, 2) + $NewName.Substring(0, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
                Write-Verbose "    > $NewName"
                break
			}

			# Desktop dd.mm.yyyy - hh.mm.ss.xx
			'^Desktop [0-9]{2}\.[0-9]{2}\.[0-9]{4} - [0-9]{2}\.[0-9]{2}\.[0-9]{2}(\.[0-9]{2})*$'
			{
				Write-Verbose "  Match: Desktop dd.mm.yyyy - hh.mm.ss.x"
                $NewName = $NewName.Split(8)
				$NewName = $NewName.Substring(6, 4) + $NewName.Substring(3, 2) + $NewName.Substring(0, 2) + "_" + $NewName.Substring(13, 2) + $NewName.Substring(16, 2) + $NewName.Substring(19, 2) + "-" + $NewName.Substring(22)
                Write-Verbose "    > $NewName"
                break
			}

			# download_yyyymmdd_hhmmss
			'^download_[0-9]{8}_[0-9]{6}$'
			{
				Write-Verbose "  Match: download_yyyymmdd_hhmmss"
                $NewName = $NewName.Substring(9)
                Write-Verbose "    > $NewName"
                break
			}

            # image_yyyymmdd_hhmmss
			'^image_[0-9]{8}_[0-9]{6}$'
			{
				Write-Verbose "  Match: download_yyyymmdd_hhmmss"
                $NewName = $NewName.Substring(6)
                Write-Verbose "    > $NewName"
                break
			}

            # Screenshot_yyyymmdd-hhmmss
            '^Screenshot_[0-9]{8}-[0-9]{6}$'
            {
                Write-Verbose "  Match: Screenshot_yyyymmdd-hhmmss"
                $NewName = $NewName.Substring(11, 8) + "_" + $NewName.Substring(20, 6)
                Write-Verbose "    > $NewName"
                break
            }

			# yyyy-mm-dd
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}( \([0-9]+\))$'
			{
				Write-Verbose "  Match: yyyy-mm-dd"
                $NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_000000"
				Write-Verbose "    > $NewName"
                break
			}

			# yyyy-mm-dd hh mm
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2}$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + "00"
                Write-Verbose "    > $NewName"
                break
			}

			# Screenshot yyyy-mm-dd hh.mm.ss
			'^Screenshot [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\.[0-9]{2}\.[0-9]{2}$'
			{
				Write-Verbose "  Match: Screenshot yyyy-mm-dd hh.mm.ss"
                $NewName = $NewName.Substring(11)
                $NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
                break
			}

			# Screenshot_yyyy-mm-dd-hh-mm-ss
			'^Screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$'
			{
				Write-Verbose "  Match: Screenshot_yyyy-mm-dd-hh-mm-ss"
				$NewName = $NewName.Substring(11)
                $NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
                break
			}

			# VID_yyyymmdd_hhmmss
			'^VID_[0-9]{8}_[0-9]{6}$'
			{
				Write-Verbose "  Match: VID_yyyymmdd_hhmmss"
				$NewName = $NewName.Substring(4)
                Write-Verbose "    > $NewName"
                break
			}

			# yyyy-mm-dd_xxxxx
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{5}$'
			{
				Write-Verbose "  Match: yyyy-mm-dd_xxxxx"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_000000"
				Write-Verbose "    > $NewName"
                break
			}

			# yyyy-mm-dd hh mm ss
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
                break
			}

			# yyyy-mm-dd hh mm ss (x)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}(_([0-9])+)? \([0-9]+\)$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (x)"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
                break
			}

			# yyyy-mm-dd hh mm ss_x
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}_([0-9])+$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
                break
			}

			# yyyy-mm-dd hh mm ss (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2} \(([a-zA-Z0-9+ ])+\)$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (xxx)"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $NewName.Substring(21)
                $NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
                break
			}

            # yyyy-mm-dd hh mm ss_x (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}_[0-9]+ \(([a-zA-Z0-9+ ])+\)$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x (xxx)"
                $Suffix = $NewName.Substring(20)
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $Suffix.Substring(0, $Suffix.IndexOf("(") -2) + "-" + $NewName.Substring($NewName.IndexOf("(") + 1)
                $NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
                break
			}

            # yyyy-mm-dd-hh-mm-ss
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
                break
			}

			# yyyy-mm-dd-hh-mm-ss_x
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}_([0-9])+$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
                break
			}

			# yyyy-mm-dd-hh-mm-ss (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}(_([0-9])+){0,1} \(([a-zA-Z0-9+ ])+\)$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (xxx)"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $NewName.Substring(21)
                $NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
                break
			}

            # yyyy-mm-dd-hh-mm-ss-(xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}(_([0-9])+){0,1}-\(([a-zA-Z0-9+ ])+\)$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (xxx)"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $NewName.Substring(21)
                $NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
                break
			}

            # yyyy-mm-dd-hh-mm-ss_x (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}_[0-9]+ \(([a-zA-Z0-9+ ])+\)$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x (xxx)"
                $Suffix = $NewName.Substring(20)
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $Suffix.Substring(0, $Suffix.IndexOf(" ")) + "-" + $NewName.Substring($NewName.IndexOf("(") + 1)
                $NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
                break
			}

			# UNKNOWN FORMAT
			default
			{
				Write-Host "Unable to determine timestamp for $($File.FullName)" -ForegroundColor Red
				$NewName = "FAIL"
				break
			}
		}
	}

	if ($NewName -ne "FAIL")
	{
		$Test = $NewName + $ext
		if ($file.Name -ne $Test) 
		{
			if (Test-Path $Test) 
			{
				$i = 1
				$Test = $NewName + "-" + $i + $ext
				if ($file.Name -ne $Test)
				{
					while (Test-Path $Test) 
					{
						$i++
						$Test = $NewName + "-" + $i + $ext
						if ($file.Name -eq $Test) 
						{
							break
						}
					}
				}
				$NewName = $NewName + "-" + $i
			}

			if ($file.Name -ne $Test) 
			{
				Write-Host "Renaming $($file.FullName) to $NewName$ext" -ForegroundColor Yellow
				Rename-Item -path $File.Name -newName "$NewName$ext"
			}
		}
		Write-Verbose "  Setting Timestamps..."
        $TimeStampStr = $NewName.Substring(0, 4) + "-" + $NewName.Substring(4, 2) + "-" + $NewName.Substring(6, 2) + " " + $NewName.Substring(9, 2) + ":" + $NewName.Substring(11, 2) + ":" + $NewName.Substring(13, 2)
		$TimeStamp = [datetime]$TimeStampStr
		Set-FileTimeStamps "$NewName$ext" $TimeStamp
	}
}
Set-Location $origDir
Write-Verbose "Restored to $origDir"
$VerbosePreference = $oldverbose

