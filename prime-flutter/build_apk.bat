@echo off
set "PATH=C:\dev\flutter\bin;C:\Program Files\Git\cmd;%PATH%"
cd /d "%~dp0"
flutter build apk --debug --dart-define=API_BASE_URL=http://2.26.86.88:8080
