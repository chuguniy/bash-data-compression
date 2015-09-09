#!/bin/bash
################################################################################
##    Bash script for file or directory compression                           ##
################################################################################
## 1. Configuration variables
##  $work - Working directory. Lock and log files reside here.
##    @MUST have tail slash! @NOT mandatory!
##  $srcdir - Directory where the source resides.
##    @MUST have tail slash!
##  $srcname - Source, file or directory to compress.
##  $dest - Destination is where the archive will be placed.
##    @MUST have tail slash!
##  $archname - Archive file name.
##    [ example: "archive_$(date +"[%Y.%m.%d - %H:%M:%S]")" ]
##  $logname - Log file name.
##  $lockname - Lock file name.
##  $checklock - Check for lock file or not.
##     If you have condition(s) in which creation of an archive is not
##     recommended or fatal (e.g. while creating snapshot, directory must not
##     be tempered with in any way) and the process which is running prior to
##     archivation (rsnapshot, rsync, rdiff etc.), can create a lock file,
##     you must switch this check ON and fill out a name for a lock file,
##     to prevent integrity violation.
##     [ default: 0 ] { 0 = off, 1 = on }
##  $locksleep - How much time to wait until next try (in milliseconds).
##    [ default: 600 ] - 10 minutes.
##  $lockwait - How many tries before script stop.
##    [ default: 12 ] - Retry for 2 hours if $locksleep = 600
##  $debug - Enable debugging or not.
##  $printtype - Set output to console and or log file.
##    [ default: "l" ] { "cl" = console & log, "l" = log only }
##  $timestamp - Timestamp format.
##    [ default: "[%Y.%m.%d - %H:%M:%S]" ]
##  $TIMEFORMAT - Output format for 'time' command.
##    [ default: "%E" ]
##  $compressor - Compressor and it's params.
##    [ default: "xz -T 4 -9 -c" ]
##  $archext - Archive extension, depending on $compressor setting.
##    [ default: ".tar.xz" ]
##
## 2. Functions
##  tstamp() - Prints timestamp.
##    [ example: "$(tstamp "[%Y.%m.%d - %H:%M:%S]")" ]
##    [ fallback: "${timestamp}" ]
##  bold() - Makes text bold.
##    [ example: "$(bold "TEST")" ]
##  printout() - Prints messages.
##    [ example: printout "Archive file name is: %s\n" "$(bold $arcname)" ]
##  checkconf() - Validates configuration.
##  checklock() - Checks for lock file.
##  execcomp() - Executes compression and assigns execution time to $exectime.
##  size() - Gets object size values.
##    @Takes two parameters, object and presentation format
##      (h - human readable, b - bytes)!
##    [ example: "$(size "$src" "b")" ]
##  compratio() - Gets compression ratio.
##    @Takes two parameters, source and archive!
##    [ example: "$(compratio "$src" "$archive")" ]
##  compinf() - Outputs compression info.
##    [ example: compinf $src $archive ]
################################################################################

## =========================== ##
## Set configuration variables ##
## =========================== ##
work="/tmp/"
srcdir="/tmp/"
srcname="testfile"
dest=$work
archname=$srcname
logname="$srcname.log"
lockname="$srcname.lock"
checklock=1
locksleep=600
lockwait=12
debug=0
## Do not change this variables if you don't know how!
printtype="l"
timestamp="[%Y.%m.%d - %H:%M:%S]"
TIMEFORMAT="%E"
compressor="xz -T 4 -9 -c"
archext=".tar.xz"

## ======================================= ##
## WARNING! Do not modify past this point! ##
## ======================================= ##

## ---------------- ##
## Global variables ##
## ---------------- ##
tb=$(tput bold) ## Bold text.
tn=$(tput sgr0) ## Normal text.
src=$srcdir$srcname ## Full path to source.
archivefn=$archname$archext ## Archive file name and extension.
archive=$dest$archname$archext ## Full path to archive.
logfile=$work$logname ## Full path to log file.
lockfile=$work$lockname ## Full path to lock file.
confok=0 ## Configuration state.
execute=0 ## Allow execution.
exectime="" ## Compression execution time.

## ------------- ##
## Initial setup ##
## ------------- ##
exec 3>&1 1>>$logfile 2>&1 ## Modifies output.

## --------- ##
## Functions ##
## --------- ##
## Sets timestamp.
tstamp() { date +"${timestamp}"; }
## Makes text bold.
bold() { echo "$tb$1$tn"; }
## Prints messages.
printout() { [[ $printtype == "l" ]] && printf "$@" || (printf "$@" \
 | tee /dev/fd/3); }
## Checks configuration.
checkconf() {
  # exec 2>/dev/null
  pass=0
  checkperm() {
    if [[ ! -n ${2} ]]; then
      [[ -r ${1} ]] && [[ -w ${1} ]] && echo 1 || echo 0;
    else
      case "$2" in
        "f" ) [[ -f ${1} ]] && [[ -r ${1} ]] && [[ -w ${1} ]] && \
         echo 1 || echo 0;;
        "d" ) [[ -d ${1} ]] && [[ -r ${1} ]] && [[ -w ${1} ]] && \
         echo 1 || echo 0;;
        "fd" ) [[ -d ${1} ]] || [[ -f ${1} ]] && [[ -r ${1} ]] && \
         [[ -w ${1} ]] && echo 1 || echo 0;;
      esac
    fi
  }
  status() { [[ $1 == 1 ]] && echo "$(bold "OK")" || echo "$(bold "NOT OK")"; }
  ## Check working directory.
  status=$(status "$(checkperm "$work" "d")")
  pass=$(( pass+$(checkperm "$work" "d")))
  [[ $debug == 1 ]] && printout \
   "\t-> Working directory is %s and is set to: %s\n" "$status" "$(bold $work)"
  ## Check source.
  status=$(status "$(checkperm "$src" "fd")")
  pass=$(( pass+$(checkperm "$src" "fd")))
  [[ $debug == 1 ]] && printout "\t-> Source is %s and is set to: %s\n" \
   "$status" "$(bold $src)"
  ## Check destination.
  status=$(status "$(checkperm "$dest" "d")")
  pass=$(( pass+$(checkperm "$dest" "d")))
  [[ $debug == 1 ]] && printout "\t-> Destination is %s and is set to: %s\n" \
   "$status" "$(bold $dest)"
  ## Display rest of the config.
  [[ $debug == 1 ]] && printout "\t-> Archive is set to: %s\n" \
   "$(bold $archivefn)"
  [[ $debug == 1 ]] && printout "\t-> Log file is set to: %s\n" \
   "$(bold $logname)"
  [[ $debug == 1 ]] && [[ $checklock == 1 ]] && printout \
  "\t-> Lock file is set to: %s\n" "$(bold $lockname)"
  [[ $debug == 1 ]] && printout "\t-> Timestamp is set to: %s\n" \
   "$(bold "$timestamp")"
  [[ $debug == 1 ]] && printout "\t-> Compressor is set to: %s\n" \
   "$(bold "$compressor")"
  ## Validate config
  if [ $pass == 3 ]; then
    confok=1; [[ $debug == 1 ]] && printout "%s Configuration is %s!\n" \
     "$(tstamp)" "$(bold "OK")"
  else
    printout "%s Configuration is %s, exiting...\n" "$(tstamp)" \
     "$(bold "NOT OK")"; exit 1
  fi
}
## Checks for lock file.
checklock() {
  for ((i=1; i<=$lockwait; i++)); do
    if [ -f ${lockfile} ]; then
      [[ $debug == 1 ]] && printout \
       "%s Lock file is in place, waiting... %s\n" "$(tstamp)" \
        "$(bold "$i")"; sleep $locksleep
    else
      i=1000
    fi
    if [ $i == $lockwait ]; then
      printout "%s Lock file is in place for to long, exiting...\n\n" "$(tstamp)"
      exit 0
    fi
  done
}
## Executes compression.
execcomp() {
  cd $srcdir || exit 1 ## Go to archive destination directory.
  exectime=$( { time tar cf - $srcname | $compressor - > $archive; } 2>&1 )
}
## Gets object size values.
size() {
  [[ $2 == "b" ]] && du -bs "$1" | awk '{ print $1 }'
  [[ $2 == "h" ]] && du -hs "$1" | awk '{ print $1 }'
}
## Gets compression ratio.
compratio() {
  res=$(let res="$1/$2"; printf "%s" "$res"); printf "%.*f" 2 "$res"
}
## Outputs compression info.
compinf() {
  printout "\t-> Source size: %s (%s bytes)\n" \
   "$(bold "$(size "$1" "h")")" "$(bold "$(size "$1" "b")")"
  printout "\t-> Archive size: %s (%s bytes)\n" \
   "$(bold "$(size "$2" "h")")" "$(bold "$(size "$2" "b")")"
  printout "\t-> Compression ratio: %s\n" \
   "$(bold "$(compratio "$(size "$1" "b")" "$(size "$2" "b")")")"
}

## ---------- ##
## Initialize ##
## ---------- ##
printout "%s Initializing...\n" "$(tstamp)"
checkconf ## Check configuration.
[[ $checklock == 1 ]] && checklock ## Check for lock file.

## Check if the old archive file exists, if it does, delete it.
if [ -f ${archive} ]; then
  [[ $debug == 1 ]] && printout "%s Old archive exists, deleting...\n" \
   "$(tstamp)"; rm -f ${archive}
  if [ ! -f ${archive} ]; then
    execute=1; [[ $debug == 1 ]] && printout \
     "%s Old archive deleted, proceeding...\n" "$(tstamp)"
  else
    printout "%s %s Can't delete old archive file, exiting...\n" \
     "$(tstamp)" "$(bold "WARNING!")"; exit 1
  fi
else
  execute=1; [[ $debug == 1 ]] && printout \
   "%s Old archive does not exist, proceeding...\n" "$(tstamp)"
fi

## Begin compression.
if [ $execute == 1 ]; then
  [[ $debug == 1 ]] && printout "%s Flag is set, executing...\n" \
   "$(tstamp)"; execcomp
  ## Check if archive file created.
  if [ -f ${archive} ]; then
    printout "%s Archive %s created in %s!\n" "$(tstamp)" "$(bold $archive)" \
     "$(bold ${exectime})"
    compinf $src $archive
    # printout "%s Process has completed successfully!\n" "$(tstamp)"
  else
    printout "%s %s Archive file was NOT created, exiting...\n" \
     "$(tstamp)" "$(bold "WARNING!")"; exit 1
  fi
else
  printout "%s Flag is NOT set, exiting...\n" "$(tstamp)"; exit 1
fi

printout "\n"; exit 0
