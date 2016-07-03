# DateFix
Rename inconsistently named photo and videos to "yyyy-mm-dd hh mm ss.ext" format and set file timestamps to match.

## Usage:

1. Create a backup of the target folder
2. Open PowerShell
3. Run


        /path/to/DateFix.ps1
4. Select the target folder
5. Answer if you want to process sub-folders
  1. Y - Process Sub Folders,
  2. N - Process selected folder only,
  3. C - Cancel, make no changes.
6. Check the results are as expected
5. Delete the backup of the target folder


You can also run


    /path/to/DateFix.ps1 -verbose
to see details of what is happening.
