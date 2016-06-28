[Reflection.Assembly]::LoadFile('C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Drawing.dll') | Out-Null
function Get-EXIFDate
{
    param( [string]$file )
    try 
    {
        $image = New-Object System.Drawing.Bitmap -ArgumentList $file
        $takenData = GetTakenData($image)
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

function GetTakenData($image) 
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

$files = Get-ChildItem -File

foreach ($file in $files)
{
    $NewName = $file.Name.Substring(0, $File.Name.Length - 4)
    $ext = $file.Name.Substring($file.Name.LastIndexOf('.'))

    #EXIF
    $EXIFDate = Get-EXIFDate $file.FullName
    if ($EXIFDate -ne $null)
    {
        $NewName = $EXIFDate
    }

    # yyyyddmm_hhmmss
    elseif ($file.Name -match '^[0-9]{8}_[0-9]{6}\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.ToCharArray()
        $NewName = $namearray[0] + $namearray[1] + $namearray[2] + $namearray[3] + "-" + $namearray[4] + $namearray[5] + "-" + $namearray[6] + $namearray[7] + " " + $namearray[9] + $namearray[10] + " " + $namearray[11] + $namearray[12] + " " + $namearray[13] + $namearray[14]
    }

    # yyyyddmm_hhmmss_n
    elseif ($file.Name -match '^[0-9]{8}_[0-9]{6}_[0-9]{1}\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.ToCharArray()
        $NewName = $namearray[0] + $namearray[1] + $namearray[2] + $namearray[3] + "-" + $namearray[4] + $namearray[5] + "-" + $namearray[6] + $namearray[7] + " " + $namearray[9] + $namearray[10] + " " + $namearray[11] + $namearray[12] + " " + $namearray[13] + $namearray[14] + $namearray[15]  + $namearray[16]
    }
    
    # IMG_yyyymmdd_hhmmss
    elseif ($file.Name -match '^IMG_[0-9]{8}_[0-9]{6}\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.Substring(4).ToCharArray()
        $NewName = $namearray[0] + $namearray[1] + $namearray[2] + $namearray[3] + "-" + $namearray[4] + $namearray[5] + "-" + $namearray[6] + $namearray[7] + " " + $namearray[9] + $namearray[10] + " " + $namearray[11] + $namearray[12] + " " + $namearray[13] + $namearray[14]
    }

    # IMG-yyyymmdd-WAnnnn
    elseif ($file.Name -match '^IMG-[0-9]{8}-WA[0-9]{4}\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.Substring(4).ToCharArray()
        $NewName = $namearray[0] + $namearray[1] + $namearray[2] + $namearray[3] + "-" + $namearray[4] + $namearray[5] + "-" + $namearray[6] + $namearray[7] + " 00 00 00_" + $namearray[14]
    }

    # Photo dd-mm-yyyy hh mm ss
    elseif ($file.Name -match '^Photo [0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2}\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.ToCharArray()
        $NewName = $namearray[6] + $namearray[7] + $namearray[8] + $namearray[9] + "-" + $namearray[3] + $namearray[4] + "-" + $namearray[0] + $namearray[1] + " " + $namearray[11] + $namearray[12] + " " + $namearray[14] + $namearray[15] + " " + $namearray[17] + $namearray[18]
    }

    # Desktop mm.dd.yyyy - hh.mm.ss.xx
    elseif ($file.Name -match '^Desktop [0-9]{2}\.[0-9]{2}\.[0-9]{4} - [0-9]{2}\.[0-9]{2}\.[0-9]{2}(\.[0-9]{2})*\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.ToCharArray()
        $NewName = $namearray[14] + $namearray[15] + $namearray[16] + $namearray[17] + "-" + $namearray[8] + $namearray[9] + "-" + $namearray[11] + $namearray[12] + " " + $namearray[21] + $namearray[22] + " " + $namearray[24] + $namearray[25] + " " + $namearray[27] + $namearray[28]
    }

    # download_yyyymmdd_hhmmss
    elseif ($file.Name -match '^download_[0-9]{8}_[0-9]{6}\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.ToCharArray()
        $NewName = $namearray[9] + $namearray[10] + $namearray[11] + $namearray[12] + "-" + $namearray[13] + $namearray[14] + "-" + $namearray[15] + $namearray[16] + " " + $namearray[18] + $namearray[19] + " " + $namearray[20] + $namearray[21] + " " + $namearray[22] + $namearray[23]
    }

    # yyyy-mm-dd
    elseif ($file.Name -match '^[0-9]{4}-[0-9]{2}-[0-9]{2}( \([0-9]+\))\.[a-z-A-Z]{3,5}$')
    {
        $NewName = $file.Name.SubString(0, 10) + " 00 00 00"
    }

    # yyyy-mm-dd hh mm
    elseif ($file.Name -match '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2}\.[a-z-A-Z0-9]{3,5}$')
    {
        $NewName = $file.Name.SubString(0, 16) + " 00"
    }

    # Screenshot yyyy-mm-dd hh.mm.ss
    elseif ($file.Name -match '^Screenshot [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\.[0-9]{2}\.[0-9]{2}\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.ToCharArray()
        $NewName = $namearray[11] + $namearray[12] + $namearray[13] + $namearray[14] + "-" + $namearray[16] + $namearray[17] + "-" + $namearray[19] + $namearray[20] + " " + $namearray[22] + $namearray[23] + " " + $namearray[25] + $namearray[26] + " " + $namearray[28] + $namearray[29]
    }

    # Screenshot_yyyy-mm-dd-hh-mm-ss.png
    elseif ($file.Name -match '^Screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}\.[a-z-A-Z0-9]{3,5}$')
    {
        $namearray = $file.Name.ToCharArray()
        $NewName = $namearray[11] + $namearray[12] + $namearray[13] + $namearray[14] + "-" + $namearray[16] + $namearray[17] + "-" + $namearray[19] + $namearray[20] + " " + $namearray[22] + $namearray[23] + " " + $namearray[25] + $namearray[26] + " " + $namearray[28] + $namearray[29]
    }


    # yyyy-mm-dd hh mm ss
    elseif ($file.Name -match '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}\.[a-z-A-Z0-9]{3,5}$')
    {
        $NewName = $file.Name.Substring(0, 19)
    }

    # yyyy-mm-dd hh mm ss (x)
    elseif ($file.Name -match '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}(_([0-9])+)? \([0-9]+\)\.[a-z-A-Z0-9]{3,5}$')
    {
        $temp = $file.Name.substring(21)
        $NewName = $file.Name.substring(0, 19) + '_' + $temp.substring(0, $temp.LastIndexOf(')'))
    }

    # yyyy-mm-dd hh mm ss_x
    elseif ($file.Name -match '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}_([0-9])+\.[a-z-A-Z0-9]{3,5}$')
    {
        $NewName = $file.Name.Substring(0, $file.Name.LastIndexOf('.'))
    }

    # yyyy-mm-dd hh mm ss (text)
    elseif ($file.Name -match '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}(_([0-9])+){0,1}( \(([a-zA-Z0-9+ ])+\)){0,1}\.[a-z-A-Z0-9]{3,5}$')
    {
        $NewName = $file.Name.Substring(0, $file.Name.LastIndexOf('.'))
    }

    # Break out
    else
    {
        Write-Host "Unable to determine timestamp for" $File.Name -ForegroundColor Red
        $NewName = "FAIL"
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
                $Warning = "Renaming $file to $NewName$ext"
                Write-Host $Warning -ForegroundColor Yellow
                Rename-Item -path $File.Name -newName "$NewName$ext"
            }
        }
        Write-Host "Setting Timestamps for $NewName$ext..."
        $TimeStampStr = $NewName.Substring(0, 13) + ":" + $NewName.Substring(14, 2) + ":" + $NewName.Substring(17, 2)
        $TimeStamp = [datetime]$TimeStampStr
        Set-FileTimeStamps "$NewName$ext" $TimeStamp
    }
}
