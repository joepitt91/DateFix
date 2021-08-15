#!/usr/bin/env python3
"""Compile a Windows executable of DateFix."""
from pyinstaller_versionfile import create_versionfile_from_input_file
from os import chdir, remove, system
from os.path import dirname
from shutil import copy

root = dirname(__file__)
chdir(root)

copy("DateFix.py", "DateFix-Win.py")
with open("DateFix-Win.py", "r") as f:
    script = f.read()
script = script.replace("DateFix.py", "DateFix.exe")
with open("DateFix-Win.py", "w") as f:
    f.write(script)

create_versionfile_from_input_file("version.txt", "version.yaml")
system("pyinstaller --clean --onefile --name DateFix --paths .DateFix\\Lib\\site-packages --icon Logo.ico --version-file version.txt DateFix-Win.py")
remove("version.txt")
remove("DateFix-Win.py")