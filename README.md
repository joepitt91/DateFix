# DateFix
**Standardise Photo and Video filenames and timestamps.**

DateFix.ps1 accepts a folder from the user then works through the files (optionally recursing) to name them as consistently as possible using the yyyyMMdd_HHmmss.ext format.

The scripts first tries to use the embedded Date Taken EXIF Date, if this is not available the file's current filename is  used.

## Usage:

1. **Create a backup of the target folder**
2. Open PowerShell
3. Run


        DateFix.ps1 [[-Path] <String>] [[-Recurse] <Boolean>] [-Verbose]
4. If -Path was not provided, then select the target folder
5. If -Recurse was not provided, then answer if you want to process sub-folders
  1. Y - Process Sub Folders,
  2. N - Process selected folder only,
  3. C - Cancel, make no changes.
6. Check the results are as expected
5. Delete the backup of the target folder

### Options

* **-Path**    The root folder to be processed, e.g. C:\Users\Username\Pictures\
* **-Recurse** Whether or not to recurse through sub-directories of the root folder.
* **-Verbose** Enables verbose output.
