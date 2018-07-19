#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
LANG=C wine reg add 'HKCU\Software\Wine\WineDbg' \
  /v ShowCrashDialog /t reg_dword /d 0 /f; exit $?
