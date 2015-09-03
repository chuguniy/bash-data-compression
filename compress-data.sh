#!/bin/bash

###############################
## Snapshot archive creation ##
###############################


## =========================== ##
## Set configuration variables ##
## =========================== ##

dest="/tmp/" ## Set destination.
src="test_file" ## Source.
archname="test_archive" ## Archive file name.
logfile="arch.log" ## Log file name.

## Do not change this variables if you don't know how!
printtype="cl" ## Set output to console & log or log only ("cl" = console & log, "l" = log only).
confdispflag=0 ## Display configuration variables in output or not.
timestamp="[%Y.%m.%d - %H:%M:%S]" ## Time stamp format.
TIMEFORMAT="%E" ## Time format for 'time' command.
compressor="xz -T 4 -9 -c" ## Compressor and it's params.
archext=".tar.xz" ## Archive extension.


## ======================================= ##
## WARNING! Do not modify past this point! ##
## ======================================= ##


## ------------- ##
## Initial setup ##
## ------------- ##

exec 3>&1 1>>$logfile 2>&1 ## Modify output.
cd $dest || exit 1 ## Go to destination or exit.


## ---------------- ##
## Global variables ##
## ---------------- ##

tb=$(tput bold) ## Bold text.
tn=$(tput sgr0) ## Normal text.
archive=$archname$archext ## Full archive file name.
execflag=0 ## Allow execution flag.
exectime="" ## Compression execution time.


## --------- ##
## Functions ##
## --------- ##

## Set timestamp.
timestamp() {	date +"${timestamp}"; }
## Bold text.
bold() { echo "$tb$1$tn"; }
## Print messages.
printout() { [[ $printtype == "cl" ]] && (printf "$@" | tee /dev/fd/3) || printf "$@"; }
## Display configuration variables.
confdisp() {
	printout "\t-> Source is set to: \t\t%s\n" "$(bold $src)"
	printout "\t-> Archive file name is set to: %s\n" "$(bold $archive)"
	printout "\t-> Log file name is set to: \t%s\n" "$(bold $logfile)"
}
## Execute compression.
execcomp() {
	res=$(time tar cf - $src | $compressor - > $archive)
	exectime=$(printf "%s" "$res")
}
## Size values.
size() {
	[[ $2 == "b" ]] && (du -bs "$1" | awk '{ print $1 }')
	[[ $2 == "h" ]] && (du -hs "$1" | awk '{ print $1 }')
}
## Compression ratio.
compratio() {
	res=$(let res="$1/$2"; printf "%s" "$res")
	printf "%.*f" 2 "$res"
}
## Display compression info.
compinf() {
	srcsizeb=$(size "$1" "b")
	srcsizeh=$(size "$1" "h")
	archsizeb=$(size "$2" "b")
	archsizeh=$(size "$2" "h")
	compratior=$(compratio "$srcsizeb" "$archsizeb")
	printout "\t-> Source size: %s (%s bytes)\n" "$(bold "$srcsizeh")" "$(bold "$srcsizeb")"
	printout "\t-> Archive size: %s (%s bytes)\n" "$(bold "$archsizeh")" "$(bold "$archsizeb")"
	printout "\t-> Compression ratio is: %s\n" "$(bold "$compratior")"
}


## ---------- ##
## Initialize ##
## ---------- ##
[[ $confdispflag == 1 ]] && confdisp
printout "%s Initializing...\n" "$(timestamp)"

## Check source.
if [ ! -d ${src} ] && [ ! -f ${src} ]; then
	printout "Source NOT found! Defined source is: %s, exiting...\n" "$(bold $src)"
	exit 1
else
	printout "%s Source %s found!\n" "$(timestamp)" "$(bold $src)"
fi

## Check if the old archive file exists, if it does, delete it.
if [ -f ${archive} ]; then
	printout "%s Old archive %s exists, deleting...\n" "$(timestamp)" "$(bold $archive)"
  rm -f ${archive}
	if [ ! -f ${archive} ]; then
		execflag=1
		printout "%s Old archive %s deleted, proceeding...\n" "$(timestamp)" "$(bold $archive)"
	else
		printout "%s %s Can't delete old archive file, exiting...\n" "$(timestamp)" "$(bold "WARNING!")"
		exit 1
	fi
else
	execflag=1
	printout "%s Old archive %s does not exist, proceeding...\n" "$(timestamp)" "$(bold $archive)"
fi

## Begin compression.
if [ ${execflag} == 1 ]; then
	printout "%s Flag is set, executing...\n" "$(timestamp)"
	execcomp
	## Check if archive file created.
	if [ -f ${archive} ]; then
		printout "%s Archive %s created in %s!\n" "$(timestamp)" "$(bold $archive)" "$(bold $exectime)"
		compinf $src $archive
		printout "%s Process has completed successfully!\n" "$(timestamp)"
	else
		printout "%s %s Something went wrong, exiting...\n" "$(timestamp)" "$(bold "WARNING!")"
		exit 1
	fi
else
	printout "%s Flag is NOT set, exiting...\n" "$(timestamp)"
	exit 1
fi

printout "\n"

exit 0