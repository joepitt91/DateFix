#!/usr/bin/env python3
"""Class definition for DateFix target files."""
from datetime import datetime, tzinfo
from logging import getLogger, INFO, debug, warning, error
from os import utime, rename
from os.path import getmtime, isfile, join, split
from re import match
from exifread import process_file
from pytz import utc

__author__ = "Joe Pitt"
__email__ = "Joe.Pitt@joepitt.uk"
__copyright__ = "Copyright (C) 2021 Joe Pitt"
__license__ = "GPL-3.0-or-later"
__version__ = "2.0.0"

# Initalise list of new names for Dry Runs
NewNames = []


class DateTimeDetectionError (Exception):
    pass


class TargetFile:
    """A file to be processed by DateFix."""

    def __init__(self, Path: str, LocalTimeZone: tzinfo, SkipEXIF: bool = False,
                 ModifiedFallback: bool = False) -> None:
        """Initalise the TargetFile object with the current and detected filenames.

        Parameters
        ----------
        Path : str
            The file to be processed

        LocalTimeZone : tzinfo, optional
            The timezone to be used for filename and timestamp setting (default is Etc/UTC)

        SkipEXIF : bool, optional
            Skips checking of EXIF data (default is False)

        ModifiedFallback : bool, optional
            Falls back to the files last modified time if all other methods fail (default is False)

        Raises
        ------
        DateTimeDetectionError
            If the timestamp cannot be detected using the enabled methods.
        """

        # Initalise optional instance variables
        self.DeduplicationID = None
        self.Extension = ""
        self.Label = None

        debug(Path)
        if not isfile(Path):
            error("{0} disappeared before processing".format(Path))
            raise FileNotFoundError(Path)
        PathParts = split(Path)
        self.Directory = PathParts[0]

        if len(PathParts[1].split(".")) > 1:
            self.Extension = ".{0}".format(PathParts[1].split(".")[-1])
        if len(self.Extension) > 0:
            self.OriginalName = PathParts[1].replace(self.Extension, "")
        else:
            self.OriginalName = PathParts[1]
        self.NewName = self.OriginalName
        self.SetNewFilename(LocalTimeZone, SkipEXIF, ModifiedFallback)
        self.RenameNeeded = (self.OriginalName != self.NewName)

    def SetNewFilename(self, LocalTimeZone: tzinfo, SkipEXIF: bool = False, ModifiedFallback: bool = False) -> bool:
        """Detect and set the new filename, using enabled methods.

        Parameters
        ----------
        LocalTimeZone : tzinfo, optional
            The timezone to be used for filename and timestamp setting (default is Etc/UTC)

        SkipEXIF : bool, optional
            Skips checking of EXIF data (default is False)

        ModifiedFallback : bool, optional
            Falls back to the files last modified time if all other methods fail (default is False)

        Raises
        ------
        DateTimeDetectionError
            If the timestamp cannot be detected using the enabled methods.
        """

        if not SkipEXIF:
            try:
                self.DateTimeFromEXIF()
                self.UpdateNewName()
                self.MatchType = "EXIF"
                return True
            except KeyError:
                # EXIF DateTimeOriginal not found in file
                pass
        try:
            self.DateTimeFromFilename()
            self.UpdateNewName()
            self.MatchType = "RegEx"
            return True
        except DateTimeDetectionError:
            pass
        if ModifiedFallback:
            warning("Falling back to Modified time for {0}".format(
                join(self.Directory, "{0}{1}".format(self.OriginalName, self.Extension))))
            self.DateTimeFromFileTimestamp(LocalTimeZone)
            self.UpdateNewName()
            return True
        else:
            warning("Failed to detect timestamp for {0}".format(
                join(self.Directory, "{0}{1}".format(self.OriginalName, self.Extension))))
            raise DateTimeDetectionError("Unable to detect timestamp")

    def DateTimeFromEXIF(self) -> bool:
        """Try to get the Date Taken attribute from embedded EXIF data.

        Raises
        ------
        KeyError
            If no EXIF DateTimeOriginal attribute is found in the detected EXIF data.
        """

        Logger = getLogger()
        LogLevel = Logger.level
        path = join(self.Directory, "{0}{1}".format(
            self.OriginalName, self.Extension))
        with open(path, 'rb') as f:
            Logger.setLevel(INFO)
            exif = process_file(f)
            Logger.setLevel(LogLevel)
            taken = str(exif["EXIF DateTimeOriginal"]).replace(
                ":", "").replace(" ", "_")
            debug("  Using EXIF Date Taken")
            self.Timestamp = taken
            self.NewName = self.Timestamp
            return True

    def DateTimeFromFilename(self) -> bool:
        """Try to detect the file's timestamp, based on filename regular expressions.

        Raises
        ------
        DateTimeDetectionError
            If no regular expression matches the original filename.
        """

        # Pattern 0: yyyymmdd_hhmmss[_n][-FreeText]
        if match(r'^[0-9]{8}_[0-9]{6}(_\d+)?(-[^\/\\?%*:|"<>. _]+)?$', self.OriginalName):
            debug("  Match: yyyymmdd_hhmmss[_n][-FreeText] (Preferred)")
            parts = match(
                r'^(?P<Timestamp>[0-9]{8}_[0-9]{6})(_(?P<DuplicateID>\d+))?(-(?P<Label>[^\/\\?%*:|"<>. _]+))?$',
                self.OriginalName)
            self.Timestamp = str(parts['Timestamp'])
            if parts['DuplicateID'] != None:
                self.DeduplicationID = int(parts['DuplicateID'])
            if parts['Label'] != None:
                self.Label = str(parts['Label'])
            return True

        # Pattern 1: yyyymmdd_hhmmss[-FreeText][_n]
        if match(r'^[0-9]{8}_[0-9]{6}(-[^\/\\?%*:|"<>. _]+)?(_\d+)?$', self.OriginalName):
            debug("  Match: yyyymmdd_hhmmss[-FreeText][_n]")
            self.Timestamp = str(self.OriginalName[0:15])
            if len(self.OriginalName) > 16:
                if self.OriginalName[15] == "-":
                    Label = self.OriginalName[16:].split("_")
                    self.Label = str(Label[0])
                    if len(Label) > 1:
                        self.DeduplicationID = int(Label[1])
                else:
                    self.DeduplicationID = int(self.OriginalName[16:])
            return True

        # Pattern 2: yyyymmdd-hhmmss[-freetext]
        elif match(r'^[0-9]{8}-[0-9]{6}(-[^\/\\?%*:|"<>. ]+)?$', self.OriginalName):
            debug("  Match: yyyymmdd-hhmmss[-freetext]")
            self.Timestamp = "{0}_{1}".format(
                self.OriginalName[0:8], self.OriginalName[9:15])
            if len(self.OriginalName) > 16:
                self.Label = self.OriginalName[16:]
            return True

        # Pattern 3: IMG_yyyymmdd_hhmmss[-n] or VID_yyyymmdd_hhmmss[-n]
        elif match(r'^(IMG|VID)_[0-9]{8}_[0-9]{6}(-[0-9]+)?$', self.OriginalName):
            debug("  Match: IMG_yyyymmdd_hhmmss")
            self.Timestamp = self.OriginalName[4:19]
            if len(self.OriginalName) > 20:
                self.DeduplicationID = int(self.OriginalName[20:])
            return True

        # Pattern 4: IMG-yyyymmdd-WAnnnn
        elif match(r'^IMG-[0-9]{8}-WA[0-9]{4}$', self.OriginalName):
            debug("  Match: IMG-yyyymmdd-WAnnnn")
            self.Timestamp = "{0}_000000".format(self.OriginalName[4:12])
            return True

        # Pattern 5: Photo dd-mm-yyyy hh mm ss
        elif match(r'^Photo [0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2} [0-9]{2} [0-9]{2}$', self.OriginalName):
            debug("  Match: Photo dd-mm-yyyy hh mm ss")
            self.Timestamp = "{0}{1}{2}_{3}{4}{5}".format(self.OriginalName[12:16], self.OriginalName[9:11],
                                                          self.OriginalName[6:8], self.OriginalName[17:19],
                                                          self.OriginalName[20:22], self.OriginalName[23:25])
            return True

        # Pattern 6: Desktop dd.mm.yyyy - hh.mm.ss.x
        elif match(r'^Desktop [0-9]{2}\.[0-9]{2}\.[0-9]{4} - [0-9]{2}\.[0-9]{2}\.[0-9]{2}\.([0-9]+)*$',
                   self.OriginalName):
            debug("  Match: Desktop dd.mm.yyyy - hh.mm.ss.x")
            self.Timestamp = "{0}{1}{2}_{3}{4}{5}".format(self.OriginalName[14:18], self.OriginalName[11:13],
                                                          self.OriginalName[8:10], self.OriginalName[21:23],
                                                          self.OriginalName[24:26], self.OriginalName[27:29])
            return True

        # Pattern 7: download_yyyymmdd_hhmmss
        elif match(r'^download_[0-9]{8}_[0-9]{6}$', self.OriginalName):
            debug("  Match: download_yyyymmdd_hhmmss")
            self.Timestamp = self.OriginalName[9:]
            return True

        # Pattern 8: image_yyyymmdd_hhmmss
        elif match(r'^image_[0-9]{8}_[0-9]{6}$', self.OriginalName):
            debug("  Match: image_yyyymmdd_hhmmss")
            self.Timestamp = self.OriginalName[6:]
            return True

        # Pattern 9: Screenshot_yyyymmdd-hhmmss
        elif match(r'^Screenshot_[0-9]{8}-[0-9]{6}$', self.OriginalName):
            debug("  Match: Screenshot_yyyymmdd-hhmmss")
            self.Timestamp = self.OriginalName[11:].replace("-", "_")
            return True

        # Pattern 10: yyyy-mm-dd
        elif match(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}( \([0-9]+\))?$', self.OriginalName):
            debug("  Match: yyyy-mm-dd")
            self.Timestamp = "{0}{1}{2}_000000".format(self.OriginalName[0:4], self.OriginalName[5:7],
                                                       self.OriginalName[8:10])
            return True

        # Pattern 11: yyyy-mm-dd hh mm
        elif match(r'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2}$', self.OriginalName):
            debug("  Match: yyyy-mm-dd hh mm")
            self.Timestamp = "{0}{1}{2}_{3}{4}00".format(self.OriginalName[0:4], self.OriginalName[5:7],
                                                         self.OriginalName[8:10], self.OriginalName[11:13],
                                                         self.OriginalName[14:16])
            return True

        # Pattern 12: Screenshot yyyy-mm-dd hh.mm.ss
        elif match(r'^Screenshot [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\.[0-9]{2}\.[0-9]{2}$', self.OriginalName):
            debug("  Match: Screenshot yyyy-mm-dd hh.mm.ss")
            self.Timestamp = self.OriginalName[11:].replace(
                "-", "").replace(" ", "_").replace(".", "")
            return True

        # Pattern 13: Screenshot_yyyy-mm-dd-hh-mm-ss
        elif match(r'^Screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$', self.OriginalName):
            debug("  Match: Screenshot_yyyy-mm-dd-hh-mm-ss")
            self.Timestamp = "{0}{1}{2}_{3}{4}{5}".format(self.OriginalName[11:15], self.OriginalName[16:18],
                                                          self.OriginalName[19:21], self.OriginalName[22:24],
                                                          self.OriginalName[25:27], self.OriginalName[28:30])
            return True

        # Pattern 14: yyyy-mm-dd_xxxxx
        elif match(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{5}$', self.OriginalName):
            debug("  Match: yyyy-mm-dd_xxxxx")
            self.Timestamp = "{0}{1}{2}_000000".format(self.OriginalName[0:4], self.OriginalName[5:7],
                                                       self.OriginalName[8:10])
            return True

        # Pattern 15: yyyy-mm-dd hh mm ss
        elif match(r'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2} [0-9]{2} [0-9]{2}(_\d+)?( \(?[^\/\\?%*:|"<>. ]+\)?)?$',
                   self.OriginalName):
            debug("  Match: yyyy-mm-dd hh mm ss")
            self.Timestamp = "{0}{1}{2}_{3}{4}{5}".format(self.OriginalName[0:4], self.OriginalName[5:7],
                                                          self.OriginalName[8:10], self.OriginalName[11:13],
                                                          self.OriginalName[14:16], self.OriginalName[17:19])
            return True

        # Pattern 16: yyyy-mm-dd-hh-mm-ss
        elif match(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}(_\d+)?( \(?[^\/\\?%*:|"<>. ]+\)?)?$',
                   self.OriginalName):
            debug("  Match: yyyy-mm-dd-hh-mm-ss")
            Parts = self.OriginalName[0:19].split("-")
            self.Timestamp = "{0}{1}{2}_{3}{4}{5}".format(
                Parts[0], Parts[1], Parts[2], Parts[3], Parts[4], Parts[5])
            return True

        # Pattern 17: WhatsApp Image yyyy-mm-dd at hh.mm.ss or WhatsApp Video yyyy-mm-dd at hh.mm.ss
        elif match(r'^WhatsApp (Image|Video) [0-9]{4}-[0-9]{2}-[0-9]{2} at [0-9]{2}.[0-9]{2}.[0-9]{2}$',
                   self.OriginalName):
            debug("    Match: WhatsApp Image/Video yyyy-mm-dd at hh.mm.ss")
            self.Timestamp = self.OriginalName[15:].replace(
                "-", "").replace(" at ", "_").replace(".", "")
            return True

        # Pattern 18: FIH_yyyyMMdd_HHmmss
        elif match(r'^FIH_[0-9]{8}_[0-9]{6}$', self.OriginalName):
            debug("  Match: FIH_yyyyMMdd_HHmmss")
            self.Timestamp = self.OriginalName[4:]
            return True

        # Pattern 19: PXL_yyyymmdd_hhmmssxxx
        elif match(r'^PXL_(?P<Timestamp>\d{8}_\d{6})\d{3}(\.(?P<Label>[A-Z]+))?$', self.OriginalName):
            debug("  Match: PXL_yyyymmdd_hhmmss")
            matches = match(r'^PXL_(?P<Timestamp>\d{8}_\d{6})\d{3}(\.(?P<Label>[A-Z]+))?$', self.OriginalName)
            self.Timestamp = matches['Timestamp']
            if matches['Label'] != None:
                self.Label = matches['Label']
            return True

        else:
            raise DateTimeDetectionError("No pattern match")

    def DateTimeFromFileTimestamp(self, TimeZone: tzinfo) -> bool:
        """Set the timestamp based on the file's last modified timestamp.

        Parameters
        ----------
        TimeZone : tzinfo
            The timezone to be used for timestamp conversion.
        """

        Path = join(self.Directory, "{0}{1}".format(
            self.OriginalName, self.Extension))
        Timestamp = getmtime(Path)
        Local = utc.localize(datetime.fromtimestamp(
            Timestamp), None).astimezone(TimeZone)
        self.Timestamp = Local.strftime("%Y%m%d_%H%M%S")
        return True

    def UpdateNewName(self) -> None:
        """Set the new filename based on the detected timestamp and label, setting Duplicate ID as needed."""

        MoveFrom = join(self.Directory, "{0}{1}".format(
            self.OriginalName, self.Extension))
        self.MergeName()
        MoveTo = join(self.Directory, "{0}{1}".format(
            self.NewName, self.Extension))

        if MoveTo in NewNames or (MoveTo != MoveFrom and isfile(MoveTo) and self.DeduplicationID == None):
            self.DeduplicationID = 1
            self.MergeName()
            MoveTo = join(self.Directory, "{0}{1}".format(
                self.NewName, self.Extension))

        while MoveTo in NewNames or (MoveTo != MoveFrom and isfile(MoveTo)):
            self.DeduplicationID = self.DeduplicationID + 1
            self.MergeName()
            MoveTo = join(self.Directory, "{0}{1}".format(
                self.NewName, self.Extension))

        NewNames.append(MoveTo)

    def MergeName(self) -> None:
        """Set the new filename based on detected timestamp, deduplication ID and label values."""

        NewName = self.Timestamp
        if self.DeduplicationID != None:
            NewName = "{0}_{1}".format(NewName, self.DeduplicationID)
        if self.Label != None:
            NewName = "{0}-{1}".format(NewName, self.Label)
        self.NewName = NewName

    def Move(self) -> bool:
        """Moves the file to its new locaton.

        Returns
        -------

        True
            If the file was moved successfully.

        False
            If the file does not need to be moved.

        Raises
        ------
        OSError
            If the file cannot be renamed
        """

        MoveFrom = join(self.Directory, "{0}{1}".format(
            self.OriginalName, self.Extension))
        MoveTo = join(self.Directory, "{0}{1}".format(
            self.NewName, self.Extension))

        if MoveTo != MoveFrom and isfile(MoveTo):
            self.DeduplicationID = 1
            self.UpdateNewName()
            MoveTo = join(self.Directory, "{0}{1}".format(
                self.NewName, self.Extension))

        while MoveTo != MoveFrom and isfile(MoveTo):
            self.DeduplicationID = self.DeduplicationID + 1
            self.UpdateNewName()
            MoveTo = join(self.Directory, "{0}{1}".format(
                self.NewName, self.Extension))
        if MoveFrom == MoveTo:
            return False
        else:
            warning("Renaming {0} to {1}{2}".format(
                MoveFrom, self.NewName, self.Extension))
            rename(MoveFrom, MoveTo)
            return True

    def FixTimestamps(self, TimeZone: tzinfo, Moved: bool) -> bool:
        """Updates the timestamps on the Target File to match the detected timestamp.

        Raises
        ------
        PermissionError
            If the timestamp cannot be set due to a permissions error
        FileNotFoundError
            If the targetted file no longer exists
        OSError
            If the timestamp cannot be set due to an underlying Operating System error
        """

        Local = TimeZone.localize(
            datetime.strptime(self.Timestamp, '%Y%m%d_%H%M%S'), None)
        UTC = Local.astimezone(utc)
        Time = UTC.timestamp()
        if Moved:
            Target = join(self.Directory, "{0}{1}".format(
                self.NewName, self.Extension))
        else:
            Target = join(self.Directory, "{0}{1}".format(
                self.OriginalName, self.Extension))
        utime(Target, (Time, Time))
        return True
