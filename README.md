# DateFix

Standardise Photo and Video filenames and timestamps.

`DateFix.py` accepts a folder from the user and works through the files, optionally recursing, to name them as
consistently as possible using the yyyyMMdd_HHmmss\[_n\].ext format. The scripts first tries to use the embedded Date
Taken EXIF Date, if this is not available the file's current filename is processed, optionally if both fail, the file's
last modified time can be used.

## Requirements (Multi-Platform)

* Python3 (required).
* venv (optional, but recommended).
* pip (optional, but recommended - alternatively manually install the packages in `requirements.txt`).

## Usage (Windows Only)

A binary of DateFix, with all dependencies bundled is available, this has been built using the `pyinstaller` and
`pyinstaller_versionfile` modules, using:

     python -m venv .DateFix
     .DateFix/Scripts/activate.ps1
     pip install -r requirements.txt
     create-version-file .\version.yaml --outfile .\version.txt
     pyinstaller --clean --onefile --name DateFix --paths .\.DateFix\Lib\site-packages\ --icon .\Logo.ico --version-file .\version.txt .\DateFix.py
     deactivate

1. Download the latest exe
2. Run DateFix `./DateFix.exe` for usage information.
3. Run DateFix with the desired options (see below).

## Installation (Multi-Platform)

1. Create a Virtual Environment `python3 -m venv .DateFix` (Linux} or `python -m venv .DateFix` (Windows).
2. Activate the Virtual Environment `source .DateFix/bin/activate` (Linux) or `.DateFix/Scripts/activate.ps1` (Windows).
3. Install dependencies `pip3 install -r requirements.txt` (Linux) or `pip install -r requirements.txt` (Windows)
4. (Unix only) Make the Python scripts executable `chmod +x *.py`

## Usage (Multi-Platform)

1. Activate the Virtual Environment, if not already active, `source .DateFix/bin/activate` (Linux) or
     `.DateFix/Scripts/activate.ps1` (Windows).
2. Run DateFix `./DateFix.py -help` for detailed usage information.
3. Run DateFix with the desired options (see below).
4. Once finished, leave the Virtual Environment `deactivate`.

### Arguments

The following arguments can be passed in any order to `./DateFix.py`:

* `<Path>` (required) - The directory to start in.
* `-DateModifiedFallback` - If EXIF and filename processing fails, revert to file modified time -
 **use with caution!** (default `False`).
* `-DryRun` - Run without renaming any files or modifying any timestampes (default `False`).
* `-Help` - Displays detailed usage information.
* `-Recurse` - Recursivly process all child directories (default `False`).
* `-Recurse=<n>` - Recursivly process child directories up to `<n>` levels deep (default `Unlimited`).
* `-SkipEXIF` - Skip EXIF checking for all files (default `False`).
* `-TimeZone=<Region>/<City>` - Sets the Time Zone to use for naming files (default `Etc/UTC`).
* `-Verbose` - Write additional output while running.

### Examples

Below are some examples of how to use DateFix.

#### ./DateFix.py ~/Pictures/

Process ~/Pictures/

#### ./DateFix.py -TimeZone=Europe/London ~/Pictures/

Process ~/Pictures/:

* Use London's Time Zone.

#### ./DateFix.py -Recurse ~/Pictures/

Process ~/Pictures/:

* Recurse an unlimited number of levels.

#### ./DateFix.py -DryRun -Recurse=2 ~/Pictures/

Process ~/Pictures/:

* Don't make any changes, and
* Recurse, up to 2 levels.

#### ./DateFix.py -Verbose ~/Pictures/Problem_Dir/

Process ~/Pictures/Problem_Dir/:

* Output debugging information.

#### ./DateFix.py -Verbose -DryRun -Recurse=5 -TimeZone=America/Los_Angeles -SkipEXIF -DateModifiedFallback MyStuff/

Process the relative path MyStuff/:

* Output debugging information,
* Don't make any changes,
* Recurse up to 5 levels,
* Use Los Angeles' Time Zone,
* Ignore EXIF data, and,
* Faill back to files' modified times.
