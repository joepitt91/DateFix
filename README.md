# DateFix
**Standardise Photo and Video filenames and timestamps.**

DateFix.ps1 accepts a folder from the user then works through the files (optionally recursing) to name them as consistently as possible using the yyyyMMdd_HHmmss.ext format.

The scripts first tries to use the embedded Date Taken EXIF Date, if this is not available the file's current filename is  used.

## Usage:

1. **Create a backup of the target folder**
2. Open PowerShell
3. Run


        DateFix.ps1 [[-Path] <String>] [-Recurse] [-Verbose]
4. If -Path was not provided, then select the target folder, and decide whether to recuse or not
6. Check the results are as expected
5. Delete the backup of the target folder

### Options

* **-Path**    The root folder to be processed, e.g. C:\Users\Username\Pictures\
* **-Recurse** Recurse through sub-directories of the root folder.
* **-Verbose** Enables verbose output.
