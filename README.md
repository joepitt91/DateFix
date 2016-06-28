# DateFix
Rename inconsistently named photo and videos to "yyyy-mm-dd hh mm ss.ext" format and set file timestamps to match.

## Usage:

1. Create a backup of /path/to/target/folder/
2. Open PowerShell
3. Run the commands


        Set-Location /path/to/target/folder/
        /path/to/DateFix.ps1
4. Check the results are as expected
5. Delete the backup of /path/to/target/folder/
