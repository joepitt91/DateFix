# DateFix
**Standardise Photo and Video filenames and timestamps.**

DateFix.ps1 accepts a folder from the user then works through the files (optionally recursively) to name them as consistently as possible using the yyyyMMdd_HHmmss.ext format.

The script first tries to use the embedded Date Taken EXIF Date, if this is not available the file's current filename is used.

## Usage:

1. **Create a backup of the target folder**
2. Open PowerShell
3. Run


        DateFix.ps1 [[-Path] <String>] [-Recurse] [-DateModifiedFallback] [-Verbose]
4. If -Path was not provided, then select the target folder, and decide whether to recuse or not
6. Check the results are as expected
5. Delete the backup of the target folder

### Options

* **-Path**    The root folder to be processed, e.g. C:\Users\Username\Pictures\
* **-Recurse** Recurse through sub-directories of the root folder.
* **-DateModifiedFallback** Use file's Date Modified time if EXIF and Pattern Matching fails.
* **-DryRun** Run DateFix without writing any changes - outputs all changes that would be made.
* **-Verbose** Enables verbose output.
