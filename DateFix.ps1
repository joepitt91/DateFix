param ([switch]$verbose)
if($verbose) 
{
	$oldverbose = $VerbosePreference
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
		return $taken.ToString('yyyy-MM-dd HH mm ss')
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

Set-Location (Get-Directory)

$title = "$(Get-Location)"
Write-Verbose "Location set to $title"
$message = "Process all sub-folders too?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Process all sub-folders."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Process only the selected folder."
$cancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Do not process any folders."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $cancel)
$result = $host.ui.PromptForChoice($title, $message, $options, 1)
switch ($result) 
{
	0 { $files = Get-ChildItem -Recurse -File; Write-Verbose "Recursive Mode Enabled" }
	1 { $files = Get-ChildItem -File }
	2 { Set-Location $origDir; Write-Verbose "Aborted"; exit }
}

foreach ($file in $files)
{
	Write-Verbose $file.FullName
	Set-Location $file.DirectoryName
	$NewName = $file.Name.Substring(0, $file.Name.LastIndexOf('.'))
	$ext = $file.Name.Substring($file.Name.LastIndexOf('.'))

	#EXIF (Preferred)
	$EXIFDate = Get-EXIFDate $file.FullName
	if ($EXIFDate -ne $null)
	{
		$NewName = $EXIFDate
		Write-Verbose "  Using EXIF Date Taken"
	}
	else
	{
		Write-Verbose "  EXIF Date Taken not found, trying RegEx"
		switch -Regex ($NewName)
		{
			# yyyyddmm_hhmmss
			'^[0-9]{8}_[0-9]{6}$'
			{
				Write-Verbose "  Match: yyyyddmm_hhmmss"
				$namearray = $NewName.ToCharArray()
				$NewName = $namearray[0] + $namearray[1] + $namearray[2] + $namearray[3] + "-" + $namearray[4] + $namearray[5] + "-" + $namearray[6] + $namearray[7] + " " + $namearray[9] + $namearray[10] + " " + $namearray[11] + $namearray[12] + " " + $namearray[13] + $namearray[14]
			}
			# yyyyddmm_hhmmss_n
			'^[0-9]{8}_[0-9]{6}_[0-9]{1}$'
			{
				Write-Verbose "  Match: yyyyddmm_hhmmss_n"
				$namearray = $NewName.ToCharArray()
				$NewName = $namearray[0] + $namearray[1] + $namearray[2] + $namearray[3] + "-" + $namearray[4] + $namearray[5] + "-" + $namearray[6] + $namearray[7] + " " + $namearray[9] + $namearray[10] + " " + $namearray[11] + $namearray[12] + " " + $namearray[13] + $namearray[14] + $namearray[15]  + $namearray[16]
			}
			# IMG_yyyymmdd_hhmmss
			'^IMG_[0-9]{8}_[0-9]{6}$'
			{
				Write-Verbose "  Match: IMG_yyyymmdd_hhmmss"
				$namearray = $NewName.Substring(4).ToCharArray()
				$NewName = $namearray[0] + $namearray[1] + $namearray[2] + $namearray[3] + "-" + $namearray[4] + $namearray[5] + "-" + $namearray[6] + $namearray[7] + " " + $namearray[9] + $namearray[10] + " " + $namearray[11] + $namearray[12] + " " + $namearray[13] + $namearray[14]
			}
			# IMG-yyyymmdd-WAnnnn
			'^IMG-[0-9]{8}-WA[0-9]{4}$'
			{
				Write-Verbose "  Match: IMG-yyyymmdd-WAnnnn"
				$namearray = $NewName.Substring(4).ToCharArray()
				$NewName = $namearray[0] + $namearray[1] + $namearray[2] + $namearray[3] + "-" + $namearray[4] + $namearray[5] + "-" + $namearray[6] + $namearray[7] + " 00 00 00_" + $namearray[14]
			}
			# Photo dd-mm-yyyy hh mm ss
			'^Photo [0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2}$'
			{
				Write-Verbose "  Match: Photo dd-mm-yyyy hh mm ss"
				$namearray = $NewName.ToCharArray()
				$NewName = $namearray[6] + $namearray[7] + $namearray[8] + $namearray[9] + "-" + $namearray[3] + $namearray[4] + "-" + $namearray[0] + $namearray[1] + " " + $namearray[11] + $namearray[12] + " " + $namearray[14] + $namearray[15] + " " + $namearray[17] + $namearray[18]
			}
			# Desktop mm.dd.yyyy - hh.mm.ss.xx
			'^Desktop [0-9]{2}\.[0-9]{2}\.[0-9]{4} - [0-9]{2}\.[0-9]{2}\.[0-9]{2}(\.[0-9]{2})*$'
			{
				Write-Verbose "  Match: Desktop mm.dd.yyyy - hh.mm.ss.x"
				$namearray = $NewName.ToCharArray()
				$NewName = $namearray[14] + $namearray[15] + $namearray[16] + $namearray[17] + "-" + $namearray[8] + $namearray[9] + "-" + $namearray[11] + $namearray[12] + " " + $namearray[21] + $namearray[22] + " " + $namearray[24] + $namearray[25] + " " + $namearray[27] + $namearray[28]
			}
			# download_yyyymmdd_hhmmss
			'^download_[0-9]{8}_[0-9]{6}$'
			{
				Write-Verbose "  Match: download_yyyymmdd_hhmmss"
				$namearray = $NewName.ToCharArray()
				$NewName = $namearray[9] + $namearray[10] + $namearray[11] + $namearray[12] + "-" + $namearray[13] + $namearray[14] + "-" + $namearray[15] + $namearray[16] + " " + $namearray[18] + $namearray[19] + " " + $namearray[20] + $namearray[21] + " " + $namearray[22] + $namearray[23]
			}
			# yyyy-mm-dd
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}( \([0-9]+\))$'
			{
				Write-Verbose "  Match: yyyy-mm-dd"
				$NewName = $NewName.SubString(0, 10) + " 00 00 00"
			}
			# yyyy-mm-dd hh mm
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2}$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm"
				$NewName = $NewName.SubString(0, 16) + " 00"
			}
			# Screenshot yyyy-mm-dd hh.mm.ss
			'^Screenshot [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\.[0-9]{2}\.[0-9]{2}$'
			{
				Write-Verbose "  Match: Screenshot yyyy-mm-dd hh.mm.ss"
				$namearray = $NewName.ToCharArray()
				$NewName = $namearray[11] + $namearray[12] + $namearray[13] + $namearray[14] + "-" + $namearray[16] + $namearray[17] + "-" + $namearray[19] + $namearray[20] + " " + $namearray[22] + $namearray[23] + " " + $namearray[25] + $namearray[26] + " " + $namearray[28] + $namearray[29]
			}
			# Screenshot_yyyy-mm-dd-hh-mm-ss
			'^Screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$'
			{
				Write-Verbose "  Match: Screenshot_yyyy-mm-dd-hh-mm-ss"
				$namearray = $NewName.ToCharArray()
				$NewName = $namearray[11] + $namearray[12] + $namearray[13] + $namearray[14] + "-" + $namearray[16] + $namearray[17] + "-" + $namearray[19] + $namearray[20] + " " + $namearray[22] + $namearray[23] + " " + $namearray[25] + $namearray[26] + " " + $namearray[28] + $namearray[29]
			}
			# VID_yyyymmdd_hhmmss
			'^VID_[0-9]{8}_[0-9]{6}$'
			{
				Write-Verbose "  Match: VID_yyyymmdd_hhmmss"
				$namearray = $NewName.ToCharArray()
				$NewName = $namearray[4] + $namearray[5] + $namearray[6] + $namearray[7] + "-" + $namearray[8] + $namearray[9] + "-" + $namearray[10] + $namearray[11] + " " + $namearray[13] + $namearray[14] + " " + $namearray[15] + $namearray[16] + " " + $namearray[17] + $namearray[18]
			}
			# yyyy-mm-dd_xxxxx
			'^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{5}$'
			{
				Write-Verbose "  Match: yyyy-mm-dd_xxxxx"
				$NewName = $NewName.Substring(0, 10) + " 00 00 00"
			}
			# yyyy-mm-dd hh mm ss
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss"
				$NewName = $NewName.Substring(0, 19)
			}
			# yyyy-mm-dd hh mm ss (x)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}(_([0-9])+)? \([0-9]+\)$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (x)"
				$temp = $NewName.substring(21)
				$NewName = $NewName.substring(0, 19) + '_' + $temp.substring(0, $temp.LastIndexOf(')'))
			}
			# yyyy-mm-dd hh mm ss_x
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}_([0-9])+$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss_x"
				$NewName = $NewName
			}
			# yyyy-mm-dd hh mm ss (xxx)
			'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}(_([0-9])+){0,1}( \(([a-zA-Z0-9+ ])+\)){0,1}$'
			{
				Write-Verbose "  Match: yyyy-mm-dd hh mm ss (xxx)"
				$NewName = $NewName
			}
			# UNKNOWN FORMAT
			default
			{
				Write-Host "Unable to determine timestamp for $($File.FullName)" -ForegroundColor Red
				$NewName = "FAIL"
				continue
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
				$Test = $NewName + "_" + $i + $ext
				if ($file.Name -ne $Test) 
				{
					while (Test-Path $Test) 
					{
						$i++
						$Test = $NewName + "_" + $i + $ext
						if ($file.Name -eq $Test) 
						{
							break
						}
					}
				}
				$NewName = $NewName + "_" + $i
			}

			if ($file.Name -ne $Test) 
			{
				Write-Host "Renaming $($file.FullName) to $NewName$ext" -ForegroundColor Yellow
				Rename-Item -path $File.Name -newName "$NewName$ext"
			}
		}
		Write-Verbose "  Setting Timestamps..."
		$TimeStampStr = $NewName.Substring(0, 13) + ":" + $NewName.Substring(14, 2) + ":" + $NewName.Substring(17, 2)
		$TimeStamp = [datetime]$TimeStampStr
		Set-FileTimeStamps "$NewName$ext" $TimeStamp
	}
}
Set-Location $origDir
Write-Verbose "Restored to $origDir"
$VerbosePreference = $oldverbose