# CalDoo (卡嘟)

[![CI](https://github.com/OSerHuang/caldoo/actions/workflows/ci.yml/badge.svg)](https://github.com/OSerHuang/caldoo/actions/workflows/ci.yml)
[![coverage](https://raw.githubusercontent.com/OSerHuang/caldoo/badges/coverage.svg)](https://github.com/OSerHuang/caldoo/actions/workflows/ci.yml)

English | [简体中文](README.md)

An offline-first Android diet tracker: log a meal by photo or text, get
energy and salt automatically, and keep every record on the device. (The app
UI is Chinese-only.)

## Features

- **Log a meal**: by photo (AI analysis) or typed / keyboard-microphone
  dictation; browse back on the Overview to backfill a past day (the meal
  type is editable). An AI failure never blocks saving
- **Food library**: photograph a printed nutrition label to create a food
  entry (one photo may contain several labels); every food is searchable and
  reusable
- **Overview**: daily / weekly / monthly energy and salt, swipe through
  history; daily exercise burn is entered manually
- **Local data + auto backup**: all records stay on the device and are
  automatically backed up to the public folder `下载/caldoo/` (newest 10
  kept); restore under Profile → Data backup. When updating, install over the
  existing app — never uninstall first (that wipes the data)
- **Display units**: kcal↔kJ and salt↔sodium, switchable anytime, display only

## Configure AI (BYOK)

Analysis runs on your own API key, stored in the system secure storage —
never in the database, logs, or backups.

1. Open **Profile → Settings → Model settings**
2. Paste your API key (`sk-...`) → **Save**, optionally **Test connection** to
   verify
3. Defaults: `https://api.deepseek.com` + `deepseek-flash`; any
   OpenAI-compatible endpoint can be set in place of them
