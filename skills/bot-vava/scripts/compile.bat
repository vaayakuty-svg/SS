@echo off
REM Quick MetaEditor command-line compile.
REM Usage: compile.bat "C:\Program Files\<Broker> MetaTrader 5" "C:\...\MQL5\Experts\MyEA\MyEA.mq5"
REM The log is written next to the source as <name>.compile.log (UTF-16). Parse it with parse_compile_log.py.
setlocal
set "MT5=%~1"
set "SRC=%~2"
if "%MT5%"=="" goto usage
if "%SRC%"=="" goto usage
set "LOG=%~dpn2.compile.log"
if exist "%LOG%" del "%LOG%"
"%MT5%\metaeditor64.exe" /compile:"%SRC%" /log:"%LOG%"
REM MetaEditor's exit code is not a reliable error count: read the Result line in the log.
type "%LOG%"
REM the log is UTF-16: "type" converts it, findstr alone would not
type "%LOG%" | findstr /c:" 0 errors" >nul && (echo [compile] 0 errors & exit /b 0)
echo [compile] errors found or no result line - see %LOG%
exit /b 1
:usage
echo Usage: compile.bat "^<MT5 install folder^>" "^<full path to EA.mq5^>"
exit /b 2
