<# 
.SYNOPSIS 
    Standardise Photo and Video filenames and timestamps.
.DESCRIPTION 
    DateFix.ps1 accepts a folder from the user then works through the files (optionally recursing) to name them as consistently as possible using the yyyyMMdd_HHmmss.ext format.
    
    The scripts first tries to use the embedded Date Taken EXIF Date, if this is not available the file's current filename is used.
.PARAMETER Path
    The root folder to be processed, e.g. C:\Users\Username\Pictures\
.PARAMETER Recurse
    Enables recursing through sub-directories of the root folder.
.PARAMETER DateModifiedFallback
    Falls back to the files Date Modified value if EXIF and pattern matching fails.
.PARAMETER DryRun
    Run DateFix without writing any changes - outputs all changes that would be made.
.PARAMETER Verbose
    Enables verbose output.
.EXAMPLE
    DateFix.ps1
    Get asked for Path and whether to recurse or not.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\
    Process C:\Users\Username\Pictures\ only.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\ -Recurse
    Recursively Process C:\Users\Username\Pictures\.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\ -Recurse -Verbose
    Recursively Process C:\Users\Username\Pictures\ with verbose output.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\ -DryRun
    Process C:\Users\Username\Pictures\ only, without making any changes, showing which files would be renamed.
.EXAMPLE
    DateFix.ps1 -Path C:\Users\Username\Pictures\ -DryRun -Verbose
    Process C:\Users\Username\Pictures\ only, without making any changes, showing which files would be renamed and what timestamps would be set.
.NOTES 
    Author  : Joe Pitt
    Version : v1.9.0 (2020-09-28)
    License : This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or(at your option) any later version.
.LINK 
    https://www.joepitt.co.uk/Project/DateFix/
#>
param ([string]$Path, [switch]$Recurse, [switch]$DateModifiedFallback, [switch]$DryRun, [switch]$Verbose)


$oldverbose = $VerbosePreference
if ($Verbose) {
	$VerbosePreference = "continue" 
}

[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null

# Get the directory to be processed.
function Get-Directory() {   
	$FolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog 
	$FolderDialog.Description = "Select Folder to process"
	$FolderDialog.ShowNewFolderButton = $false
	$FolderDialog.ShowDialog() | Out-Null
	$FolderDialog.SelectedPath
}

# Load the iamge and pass it to Get-TakenDate
function Get-EXIFDate {
	param( [string]$file )
	try {
		$image = New-Object System.Drawing.Bitmap -ArgumentList $file
		$takenData = Get-TakenData($image)
		if ($null -eq $takenData) {
			$image.Dispose()
			return $null
		}
		$takenValue = [System.Text.Encoding]::Default.GetString($takenData, 0, $takenData.Length - 1)
		$taken = [DateTime]::ParseExact($takenValue, 'yyyy:MM:dd HH:mm:ss', $null)
		$image.Dispose()
		return $taken.ToString('yyyyMMdd_HHmmss')
	}
	catch {
		return $null
	}
}

# Read the EXIF Taken Date from the provided image.
function Get-TakenData($image) {
	try {
		return $image.GetPropertyItem(36867).Value
	}   
	catch {
		return $null
	}
}

# Sets the file's timestamps to the provided datetime.
Function Set-FileTimeStamps {
	param ( [Parameter(mandatory = $true)] [string[]]$path, [datetime]$date = (Get-Date) )
	Get-ChildItem -Path $path |
	ForEach-Object {
		if ($_.CreationTime -ne $date) {
			Write-Verbose "  Setting Creation Time..."
			$_.CreationTime = $date
		}
		if ($_.LastWriteTime -ne $date) {
			Write-Verbose "  Setting Modified Time..."
			$_.LastWriteTime = $date
		}
		if ($_.LastAccessTime -ne $date) {
			Write-Verbose "  Setting Last Accessed Time..."
			$_.LastAccessTime = $date
		}
	}
}

$origDir = $(Get-Location)
Write-Verbose "Original Location $origDir"

# Get and Test path
if ($PSBoundParameters.ContainsKey('Path')) {
	if (Test-Path "$Path") {
		Set-Location "$Path"
		Write-Verbose "Using '$Path'"
	}
	else {
		Write-Error -Message "Path does not exist." -RecommendedAction "Check path and try again" -ErrorId "1" `
			-Category ObjectNotFound -CategoryActivity "Testing Path Exists" -CategoryReason "The Path was not found" `
			-CategoryTargetName "$Path" -CategoryTargetType "Directory"
		exit 1
	}
}
else {
	$Path = Get-Directory
	if (Test-Path "$Path") {
		Set-Location "$Path"
		Write-Verbose "Using '$Path'"
	}
	else {
		Write-Error -Message "Path does not exist." -RecommendedAction "Check path and try again" -ErrorId "1" `
			-Category ObjectNotFound -CategoryActivity "Testing Path Exists" -CategoryReason "The Path was not found" `
			-CategoryTargetName "$Path" -CategoryTargetType "Directory"
		exit 1
	}

	$message = "Process all sub-folders too?"
	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Process all sub-folders."
	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Process only the selected folder."
	$cancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Do not process any folders."
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $cancel)
	$result = $host.ui.PromptForChoice($title, $message, $options, 1)
	switch ($result) {
		0 { $Recurse = $true }
		1 { $Recurse = $false }
		2 { Set-Location $origDir; Exit 2 }
	}
}

# Get Files
if ($Recurse) {
	$files = Get-ChildItem -Recurse -File
	Write-Verbose "Recursive Mode Enabled"
}
else {
	$files = Get-ChildItem -File
}

# Process Files
foreach ($file in $files) {
	Write-Verbose $file.FullName
	Set-Location $file.DirectoryName
	$NewName = $file.Name.Substring(0, $file.Name.LastIndexOf('.'))
	$Extension = $file.Name.Substring($file.Name.LastIndexOf('.'))

	## Detect DateTime

	# EXIF (Preferred)
	$EXIFDate = Get-EXIFDate $file.FullName
	if ($null -ne $EXIFDate) {
		# Check if filename is already compliant
		if ($NewName -match "^$EXIFDate(-[^/\\?%*:|`"<>. ]+)?$") {
			Write-Verbose "  Using EXIF Date Taken - Name already compliant"
		}
		else {
			# Check if filename is compliant, with free text, but with wrong timestamp
			if ($NewName -match '^[0-9]{8}_[0-9]{6}-[^/\\?%*:|"<>. ]+$') {
				$FreeText = $NewName.Substring($NewName.IndexOf('-') + 1)
				$NewName = "$EXIFDate-$FreeText"
				Write-Verbose "  Using EXIF Date Taken - Keeping free text"
				Write-Verbose "    > $NewName"
			}
			else {
				$NewName = $EXIFDate
				Write-Verbose "  Using EXIF Date Taken"
				Write-Verbose "    > $NewName"
			}
		}
	}
	# Filename Fallback
	else {
		Write-Verbose "  EXIF Date Taken not found, trying RegEx"
		switch -Regex ($NewName) {
			# Preferred Format yyyymmdd_hhmmss or yyyymmdd_hhmmss-FreeText
			'^[0-9]{8}_[0-9]{6}(-[^/\\?%*:|"<>. ]+)?$' {
				Write-Verbose "  Match: yyyymmdd_hhmmss or yyyymmdd_hhmmss-FreeText (Preferred)"
				break
			}

			# yyyymmdd-hhmss
			'^[0-9]{8}-[0-9]{6}$' {
				Write-Verbose "  Match: yyyymmdd-hhmmss"
				$NewName = $NewName.Replace('-', '_')
				Write-Verbose "    > $NewName"
				break
			}

			# yyyymmdd_hhmmss_n
			'^[0-9]{8}_[0-9]{6}_[^/\\?%*:|"<>. ]+$' {
				Write-Verbose "  Match: yyyymmdd_hhmmss_n"
				$NewName = $NewName.Substring(0, 15) + "-" + $NewName.Substring(16)
				Write-Verbose "    > $NewName"
				break
			}

			# IMG_yyyymmdd_hhmmss or IMG_yyyymmdd_hhmmss~x
			'^IMG_[0-9]{8}_[0-9]{6}(~[0-9]+)$' {
				Write-Verbose "  Match: IMG_yyyymmdd_hhmmss"
				$NewName = $NewName.Substring(4)
				Write-Verbose "    > $NewName"
				break
			}

			# IMG-yyyymmdd-WAnnnn
			'^IMG-[0-9]{8}-WA[0-9]{4}$' {
				Write-Verbose "  Match: IMG-yyyymmdd-WAnnnn"
				$NewName = "$($NewName.Substring(4, 8))_000000"
				Write-Verbose "    > $NewName"
				break
			}

			# Photo dd-mm-yyyy hh mm ss
			'^Photo [0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2}$' {
				Write-Verbose "  Match: Photo dd-mm-yyyy hh mm ss"
				$NewName = $NewName.Substring(6)
				$NewName = $NewName.Substring(6, 4) + $NewName.Substring(3, 2) + $NewName.Substring(0, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# Desktop dd.mm.yyyy - hh.mm.ss.xx
			'^Desktop [0-9]{2}\.[0-9]{2}\.[0-9]{4} - [0-9]{2}\.[0-9]{2}\.[0-9]{2}(\.[0-9]{2})*$' {
				Write-Verbose "  Match: Desktop dd.mm.yyyy - hh.mm.ss.x"
				$NewName = $NewName.Split(8)
				$NewName = $NewName.Substring(6, 4) + $NewName.Substring(3, 2) + $NewName.Substring(0, 2) + "_" + $NewName.Substring(13, 2) + $NewName.Substring(16, 2) + $NewName.Substring(19, 2) + "-" + $NewName.Substring(22)
				Write-Verbose "    > $NewName"
				break
			}

			# download_yyyymmdd_hhmmss
			'^download_[0-9]{8}_[0-9]{6}$' {
				Write-Verbose "  Match: download_yyyymmdd_hhmmss"
				$NewName = $NewName.Substring(9)
				Write-Verbose "    > $NewName"
				break
			}

			# image_yyyymmdd_hhmmss
			'^image_[0-9]{8}_[0-9]{6}$' {
				Write-Verbose "  Match: download_yyyymmdd_hhmmss"
				$NewName = $NewName.Substring(6)
				Write-Verbose "    > $NewName"
				break
			}

			# Screenshot_yyyymmdd-hhmmss
			'^Screenshot_[0-9]{8}-[0-9]{6}$' {
				Write-Verbose "  Match: Screenshot_yyyymmdd-hhmmss"
				$NewName = $NewName.Substring(11, 8) + "_" + $NewName.Substring(20, 6)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}( \([0-9]+\))$' {
				Write-Verbose "  Match: yyyy-mm-dd"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_000000"
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd hh mm
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2}$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + "00"
				Write-Verbose "    > $NewName"
				break
			}

			# Screenshot yyyy-mm-dd hh.mm.ss
			'^Screenshot [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\.[0-9]{2}\.[0-9]{2}$' {
				Write-Verbose "  Match: Screenshot yyyy-mm-dd hh.mm.ss"
				$NewName = $NewName.Substring(11)
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# Screenshot_yyyy-mm-dd-hh-mm-ss
			'^Screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$' {
				Write-Verbose "  Match: Screenshot_yyyy-mm-dd-hh-mm-ss"
				$NewName = $NewName.Substring(11)
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# VID_yyyymmdd_hhmmss
			'^VID_[0-9]{8}_[0-9]{6}$' {
				Write-Verbose "  Match: VID_yyyymmdd_hhmmss"
				$NewName = $NewName.Substring(4)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd_xxxxx
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{5}$' {
				Write-Verbose "  Match: yyyy-mm-dd_xxxxx"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_000000"
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd hh mm ss
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd hh mm ss (x)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}(_([0-9])+)? \([0-9]+\)$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (x)"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd hh mm ss_x
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}_([0-9])+$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd hh mm ss (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2} \(([a-zA-Z0-9+ ])+\)$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (xxx)"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $NewName.Substring(21)
				$NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd hh mm ss_x (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}_[0-9]+ \(([a-zA-Z0-9+ ])+\)$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x (xxx)"
				$Suffix = $NewName.Substring(20)
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $Suffix.Substring(0, $Suffix.IndexOf("(") - 2) + "-" + $NewName.Substring($NewName.IndexOf("(") + 1)
				$NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd-hh-mm-ss
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd-hh-mm-ss_x
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}_([0-9])+$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd-hh-mm-ss (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}(_([0-9])+){0,1} \(([a-zA-Z0-9+ ])+\)$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (xxx)"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $NewName.Substring(21)
				$NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd-hh-mm-ss-(xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}(_([0-9])+){0,1}-\(([a-zA-Z0-9+ ])+\)$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (xxx)"
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $NewName.Substring(21)
				$NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
				break
			}

			# yyyy-mm-dd-hh-mm-ss_x (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}_[0-9]+ \(([a-zA-Z0-9+ ])+\)$' {
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x (xxx)"
				$Suffix = $NewName.Substring(20)
				$NewName = $NewName.Substring(0, 4) + $NewName.Substring(5, 2) + $NewName.Substring(8, 2) + "_" + $NewName.Substring(11, 2) + $NewName.Substring(14, 2) + $NewName.Substring(17, 2) + "-" + $Suffix.Substring(0, $Suffix.IndexOf(" ")) + "-" + $NewName.Substring($NewName.IndexOf("(") + 1)
				$NewName = $NewName.Substring(0, $NewName.Length)
				Write-Verbose "    > $NewName"
				break
			}
			
			# WhatsApp Image/Video yyyy-mm-dd at hh.mm.ss
			'^WhatsApp (Image|Video) [0-9]{4}-[0-9]{2}-[0-9]{2} at [0-9]{2}.[0-9]{2}.[0-9]{2}$' {
				Write-Verbose "    Match: WhatsApp Image/Video yyyy-mm-dd at hh.mm.ss"
				$NewName = $NewName.Substring(15, 4) + $NewName.Substring(20, 2) + $NewName.Substring(23, 2) + "_" + $NewName.Substring(29, 2) + $NewName.Substring(32, 2) + $NewName.Substring(35, 2)
				Write-Verbose "    > $NewName"
				break
			}

			# FIH_yyyyMMdd_HHmmss
			'^FIH_[0-9]{8}_[0-9]{6}$' {
				Write-Verbose "  Match: FIH_yyyyMMdd_HHmmss"
				$NewName = $NewName.Substring(4)
				Write-Verbose "    > $NewName"
				break
			}

			# UNKNOWN FORMAT
			default {
				if ($DateModifiedFallback) {
					Write-Verbose "    Unable to determine timestamp, falling back to Date Modified."
					$NewName = $file.LastWriteTime.ToString("yyyyMMdd_HHmmss")
					Write-Verbose "    > $NewName"
				}
				else {
					Write-Error -Message "Unable to determine timestamp" -Category ParserError -ErrorId 2 -TargetObject $file.FullName `
						-RecommendedAction "Manually Rename the file" -CategoryActivity "Detect new filename" `
						-CategoryReason "EXIF Not Found and No Pattern Match" -CategoryTargetType "File"
					$NewName = "FAIL"
				}
				break
			}
		}
	}

	if ($NewName -ne "FAIL") {
		$Test = $NewName + $Extension
		if ($file.Name -ne $Test) {
			if (Test-Path $Test) {
				$i = 1
				$Test = $NewName + "-" + $i + $Extension
				if ($file.Name -ne $Test) {
					while (Test-Path $Test) {
						$i++
						$Test = $NewName + "-" + $i + $Extension
						if ($file.Name -eq $Test) {
							break
						}
					}
				}
				$NewName = $NewName + "-" + $i
			}

			if ($file.Name -ne $Test) {
				if ($DryRun) {
					Write-Warning "  [Dry Run] Would rename $($file.FullName) to $NewName$Extension"
				}
				else {
					Write-Host "  Renaming $($file.FullName) to $NewName$Extension"
					Rename-Item -path $File.Name -newName "$NewName$Extension"
				}
			}
		}
		$TimeStampStr = $NewName.Substring(0, 4) + "-" + $NewName.Substring(4, 2) + "-" + $NewName.Substring(6, 2) + " " + $NewName.Substring(9, 2) + ":" + $NewName.Substring(11, 2) + ":" + $NewName.Substring(13, 2)
		if ($DryRun) {
			Write-Verbose "  [Dry Run] Would set timestamps on $NewName$Extension to $TimeStampStr"
		}
		else {
			$TimeStamp = [datetime]$TimeStampStr
			Set-FileTimeStamps "$NewName$Extension" $TimeStamp
		}
	}
}
Set-Location $origDir
Write-Verbose "Restored to $origDir"
$VerbosePreference = $oldverbose
