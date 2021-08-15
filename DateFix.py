#!/usr/bin/env python3
"""Standardise Photo and Video filenames and timestamps."""
from logging import basicConfig, getLogger, DEBUG, INFO, debug, info, warning, error
from os import walk, sep
from os.path import isdir, join
from sys import argv, exit
from pytz import timezone, UnknownTimeZoneError
from TargetFile import TargetFile, DateTimeDetectionError

__author__ = "Joe Pitt"
__email__ = "Joe.Pitt@joepitt.uk"
__copyright__ = "Copyright (C) 2021 Joe Pitt"
__license__ = "GPL-3.0-or-later"
__version__ = "2.0.0"

print("DateFix v2.0.0 (2021-08-15), Copyright (C) 2021 Joe Pitt")
print("This program comes with ABSOLUTELY NO WARRANTY.")
print("This is free software, and you are welcome to redistribute it under certain conditions; \
see https://www.gnu.org/licenses/gpl-3.0.txt for details.")
print()

# Configure Logging
basicConfig(format="%(asctime)s %(levelname)-7s %(message)s")
Logger = getLogger()
Logger.setLevel(INFO)

# Initalise configuration
Path = None
TimeZone = timezone("Etc/UTC")
Recurse = False
RecurseLevels = None
SkipEXIF = False
DateModifiedFallback = False
DryRun = False
Verbose = False
# Initalise Counters
Processed = 0
Matched = 0
Renamed = 0
Failures = 0

# Process arguments
if len(argv) > 1:
    argv.pop(0)
    for arg in argv:
        if arg.lower().startswith("-timezone="):
            arg = arg.split("=")[1]
            try:
                TimeZone = timezone(arg)
                debug("Time Zone set to {0}".format(arg))
            except UnknownTimeZoneError:
                error(
                    "Invalid Time Zone, must be in Region/City format, e.g. Europe/London.")
                exit()

        elif arg.lower() == "-recurse":
            Recurse = True
            debug("Recurse enabled")

        elif arg.lower().startswith("-recurse="):
            levels = arg[9:]
            try:
                RecurseLevels = int(levels)
                if RecurseLevels < 1:
                    raise ValueError("Recusion Levels less than 1")
                Recurse = True
                debug("Recurse enabled, and limited to {0} levels".format(
                    RecurseLevels))
            except ValueError:
                error(
                    "Invalid number of recusion levels, must be at least 1.")
                exit()

        elif arg.lower() == "-skipexif":
            SkipEXIF = True
            debug("EXIF processing disabled")

        elif arg.lower() == "-datemodifiedfallback":
            DateModifiedFallback = True
            debug("Date Modified Fallback enabled")

        elif arg.lower() == "-dryrun":
            DryRun = True
            debug("Dry Run Enabled")

        elif arg.lower() == "-verbose":
            Verbose = True
            Logger.setLevel(DEBUG)
            debug("Verbose output enabled")

        elif arg.lower() == "-help":
            print("DateFix - Standardise Photo and Video filenames and timestamps.")
            print()
            print(
                "Usage: DateFix.py [-Verbose] [-TimeZone=<Region>/<City>] [-Recurse[=<levels>]] [-SkipEXIF] \
[-DateModifiedFallback] [-DryRun] <Path>")
            print()
            print("<Path> (required)")
            print("    The directory to start in.")
            print("-DateModifiedFallback")
            print("    If EXIF and filename processing fails, revert to file modified time - use with caution! \
(default False).")
            print("-DryRun")
            print(
                "    Run without renaming any files or modifying any timestampes (default False).")
            print("-Recurse")
            print("    Recursivly process all child directories (default False).")
            print("-Recurse=<n>")
            print(
                "    Recursivly process child directories up to <n> levels deep (default Unlimited).")
            print("-SkipEXIF")
            print("    Skip EXIF checking for all files (default False).")
            print("-TimeZone=<Region>/<City>")
            print("    Sets the Time Zone to use for naming files (default Etc/UTC).")
            print("-Verbose")
            print("    Write additional output while running.")
            exit()

        elif isdir(arg):
            if Path == None:
                Path = arg
                debug("Using '{0}' as root directory".format(arg))
            else:
                error("Multiple paths provided, expected one.")
                print(
                    "Usage: DateFix.py [-Verbose] [-TimeZone=<Region>/<City>] [-Recurse[=<levels>]] [-SkipEXIF] \
[-DateModifiedFallback] [-DryRun] <Path>")
                print("Help: DateFix.py -Help")
                exit()

        else:
            if arg.startswith("-"):
                error("Invalid argument '{0}'".format(arg))
            else:
                error(
                    "Invalid path '{0}', must be an existing directory".format(arg))
            print(
                "Usage: DateFix.py [-Verbose] [-TimeZone=<Region>/<City>] [-Recurse[=<levels>]] [-SkipEXIF] \
[-DateModifiedFallback] [-DryRun] <Path>")
            print("Help: DateFix.py -Help")
            exit()

# If no path provided, show usage message
if Path == None:
    print(
        "Usage: DateFix.py [-Verbose] [-TimeZone=<Region>/<City>] [-Recurse[=<levels>]] [-SkipEXIF] [-DateModifiedFallback] \
[-DryRun] <Path>")
    print("Help: DateFix.py -Help".format(str(__file__)))
    exit()

debug("Getting files")
for root, directories, files in walk(Path):
    recurseTest = root.replace(Path, "")
    if RecurseLevels == None or root[len(Path):].count(sep) <= RecurseLevels:
        files.sort()
        for file in files:
            Processed = Processed + 1
            path = join(root, file)
            try:
                File = TargetFile(
                    path, TimeZone, SkipEXIF, DateModifiedFallback)
                Matched = Matched + 1
                if File.RenameNeeded:
                    if DryRun:
                        warning("Would rename {0} to {1}{2}".format(
                            path, File.NewName, File.Extension))
                    else:
                        try:
                            if File.Move():
                                Renamed = Renamed + 1
                                try:
                                    File.FixTimestamps(TimeZone, True)
                                except (FileNotFoundError, PermissionError):
                                    error("Failed to set file timestamps on {0}".format(
                                        join(File.Directory, "{0}{1}".format(File.NewName, File.Extension))))
                                    Failures = Failures + 1
                            else:
                                try:
                                    File.FixTimestamps(TimeZone, False)
                                except (FileNotFoundError, PermissionError):
                                    error("Failed to set file timestamps on {0}".format(
                                        join(File.Directory, "{0}{1}".format(File.OriginalName, File.Extension))))
                                    Failures = Failures + 1
                        except OSError:
                            error("Failed to move {0} to {1}".format(
                                path, "{0}{1}".format(File.NewName, File.Extension)))
                            Failures = Failures + 1
                elif not File.RenameNeeded and not DryRun:
                    try:
                        File.FixTimestamps(TimeZone, False)
                    except (FileNotFoundError, PermissionError):
                        error("Failed to set file timestamps on {0}".format(
                            join(File.Directory, "{0}{1}".format(File.OriginalName, File.Extension))))
                        Failures = Failures + 1
            except DateTimeDetectionError:
                continue

    if not Recurse:
        break

info("Done. Processed {0} files, matching {1} and renaming {2}".format(
    Processed, Matched, Renamed))
if Failures > 0:
    warning("{0} rename(s) failed".format(Failures))
