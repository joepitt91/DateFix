# Windows

A Windows executable of DateFix is available, or can be built locally.

**Note:** Some Anti-Virus solutions may falsely detect the executable as malware, this is due to benign common libraries
also being present in malicious executables and the vendors erroneously including these as detection rules. Compiling
`pyinstaller` locally should reduce the risk of this occuring.

## Build Requirements

Beyond the requirements for DateFix, building an exe of DateFix requires:

* `pyinstaller`
* `pyinstaller_versionfile`

## Build Instructions

1. Open PowerShell in the project directory,
2. Allow unrestricted script execution: `Set-ExecutionPolicy Undefined Process`
3. Create the Virtual Environement: `python -m venv .DateFix`.
4. Activate the Virtual Environment: `.DateFix/Scripts/activate.ps1`.
5. Install the packages required by DateFix: `pip install -r requirements.txt`,
6. Run `python ./DateFix.py` to verify the Usage message appears,
7. Install the build requirements: `pip install pyinstaller pyinstaller_versionfile`,
8. Run `python ./WindowsBuild.py`,
9. Check the output for errors,
10. Run `dist/DateFix.exe` to verify the Usage message appears.

## Usage

Once downloaded or built, the exe works the same as the multi-platform py script.

1. Download, or build, `DateFix.exe`,
2. Run `./DateFix.exe -help` for detailed usage information.
3. Run DateFix with the desired options (see [README](README.md)).
