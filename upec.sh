#!/bin/bash
# this program comes with absolutely NO WARRANTY! For GLP v3 license see github
# CREDITS:
# this script is based on the initial work of TwT from the keywelt-forum. Without his
# work I would never have started this project. Thanks to him for delivering the core structure
# for EIT parsing!
# (see: http://www.keywelt-board.com/index.php?/topic/168474-enigma2-aufnahmen-abspielen/?hl=%2Benigma2+%2Beit)
# Other credits go to the wonderful bash-resources out there in the internet!
#
# Copyright:
# Copyright: TwT (from Keywelt-board), bashforever (from github).
# Released to github/upec
#
#
# =============================== added features =====================================
# 2017-01-18: new features!
#
# === Ignore Directories ===
# You can place a file (actually a semaphore) named "upecignore.txt" in a directory. Doing this
# the according directory (and all it's subdirectories!!) will not be scanned by upec. This is
# useful if you have under your recording-tree a directory holding new recordings or a working
# dir for doing conversions.
#
# === Genre Files ====
# upec takes by default the name of the current directory as genre. This may be very convenient
# but there may be cases where you would like to set the genre manually.
# With this version you can place a file named "upecgenre.txt" in a directory. Thus instead
# of the directory name the content string of upecgenre.txt will be used as genre for all
# EIT-files found in this current directory.
#
# =============== Enter or change here the Configuration according to your needs ======
# CAUTION: options are case sensitive!
BASEPATH="/etc/iwops/upec" # path where upec, logfiles and CSV shoudl reside
VIDEOPATH="/media/Recs/Aufnahmen" # root path for your video/eit-files
=======
BASEPATH="/home/immanuel/Skripts/upec" # path where upec, logfiles and CSV shoudl reside
VIDEOPATH="/home/immanuel/Videos" # root path for your video/eit-files
# VIDEOPATH="$BASEPATH"
LOGFILE="$BASEPATH""/upec.log"
DEBUGLOG="$BASEPATH""/upecdebug.log"
REBUILD="y" # if set to 'y' all nfo-files are rebuilt/overwritten
RECURSIVE="y" # if set to 'n' no subdirs will be searched for EIT-files
MINTITLELEN=25 # if the TITLE extracted from short_descriptor is shorter than MINTITLELEN the long description will be added (concatenated)
DRYRUN="n" # set DRYRUN to "y" if NFO files should not be built - then there is just logfiles and the CSV
# curr. not implemented: WRITECSV="y" # if y: fields are also written in CSV-style to "upec.csv" 
CSVFile="$BASEPATH""/upec.csv" 
CSVDelimiter="|"
DEBUG="y" # if y debug output will added
CLEARLOG="y" # if y, logfiles will be cleared on start
VIDEOEXTENSIONS="ts TS mpg MPG mp4 MP4 avi AVI mts MTS m4v"
# ============== do not change anything below ! ==============

# Global declarations and initializations
declare -A Nfo # associative array holding the target Nfo field values, e.g. the value for the title and so on
XMLstring="" # output string to be written to the target NFO-file
Genre="" # output string for genre
declare -a NfoFields # array holding the Nfo field labels (enumeration)
declare -A CSVdata # associative array holding the target CSV field values
declare -a CSVFields # array holding the CSV field labels (enumeration)
RETURN=""
if [ $CLEARLOG == "y" ]; then
	echo "" > "$LOGFILE"
	echo "" > "$DEBUGLOG"
fi

# =============== Expert configuration for CSV fields ================
# CSVFields=("title" "outline" "plot" "filename")
CSVFields=("title" "outline" "genre" "filename")
# =====================================================


# Target structure
Title=""
Outline=""
Plot=""
echo "" > "$CSVFile"

# ===================== byte_to_int - convert character to integer =========================
# parameter 1: a single character
# return: pasted into global RETURN value
function byte_to_int {
    local iresult
#    echo "Input: $1" 
#    iresult=$(echo "$1" | hexdump -n 1 -d |head -n 1 | cut -d' ' -f2)
    iresult=$(echo "$1" | hexdump -n 1 -d | head -n 1 )
    resvector=($iresult) # convert result string to array
    RETURN=${resvector[1]} # return second value from array (index starts from 0)
#    UNIT=1.0
    RETURN=$((10#$RETURN))
    logdebug "Conversion result: $iresult" # replace echo by logdebug-function
    logdebug "Integer value: $RETURN" 
}



# ===================== function LOGTEXT ======================================
# Parameter: Text der ins Logfile geschrieben werden soll
# function for writing text to logfile
function logtext () {
   echo "LOG `date`: " $1 2>&1 | tee -a "$LOGFILE"
   if [ $DEBUG == "y" ]; then
       echo "DEBUG `date`: " $1 2>&1 | tee -a "$DEBUGLOG"
   fi

}   

# ===================== function logdebug  ======================================
# Parameter: Text der ins Logfile geschrieben werden soll
# function for writing text to logfile
function logdebug () {
    if [ $DEBUG == "y" ]; then 
            echo "DEBUG `date`: " $1 2>&1 | tee -a "$DEBUGLOG"
    fi
} 

# ===================== parse video filename =====================================
# Parameter: Videofilename
# Output: via global variable "RETURN"
function parsevideoname () {
Input="$1"
Separator=" - "

logdebug "Parse Input: $Input"

# check for input starting with date-time-string
if [[ "$Input" =~ ^[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])[[:space:]][0-9]{4}* ]]; then
    logdebug "Valid date"
# extract year (first 4 digits)
# echo "US/Central - 10:26 PM (CST)" | sed -n "s/^.*-\s*\(\S*\).*$/\1/p"
# 
# -n      suppress printing
# s       substitute
# ^.*     anything at the beginning
# -       up until the dash
# \s*     any space characters (any whitespace character)
# \(      start capture group
# \S*     any non-space characters
# \)      end capture group
# .*$     anything at the end
# \1      substitute 1st capture group for everything on line
# p       print it

    Year=${Input:0:4}
    logdebug "filebased Year $Year"
    # search for separator
    if [[ $Input == *"$Separator"* ]]; then
        logdebug "Separator: 8 $Separator 8 found"
        Title=$(echo "$Input" | sed -n 's/^.*'"$Separator"'/ /p')
    fi
    RETURN="$Title"
    logdebug "filebased Title $Title, returning $RETURN"

else
    RETURN="$Input"
    logdebug "Invalid date in video file name, returning $RETURN"
fi

}

# search for separator
if [[ $Input == *"$Separator"* ]]; then
    logdebug "Separator found"
#    Output=$(echo "$Input" | sed -n "s/^.*"$Separator"*"$Separator"/\1/p")
    Output=$(echo "$Input" | sed -n 's/^.*'"$Separator"'/ /p')
fi

logdebug "Output: $Output"
# return: pasted into global RETURN value
RETURN="$Output"

#EIF

# ===================== function recursive_scan ======================================
# Parameter: none, recursive_scan assumes that intended working dir is $PWD
# Caution: 

function recursive_scan () {
#       local TARGET=$1
        local filetrunc
	
#        cd "$TARGET"
        logtext "===== Current working dir `pwd`"

# set genre by current dir (full path stripped)
	Genre=${PWD##*/}
 	logtext "==== Current dir: $PWD ==== Genre by directory: $Genre"
# check for upecgenre. If a upecgenre.txt file is found, use it's content for genre
 	if [ -e "upecgenre.txt" ]; then
 	    Genre=$(cat "upecgenre.txt")
 	    logtext "==== Genre for this directory overwritten with $Genre from upecgenre"
 	fi

# 	loop over all files/dirs in current dir
	for d in *; do
		if [ -d "$d"  ] && [  $RECURSIVE = "y" ]; then
	# object is directory (and not SAVE)
			logtext "==== jumping to subdir $d ===="
 			cd "$d"
 	# set genre by current dir (full path stripped)
 			Genre=${PWD##*/}
 			logtext "==== Current dir: $PWD ==== Genre by directory: $Genre"
 	# check for upecgenre. If a upecgenre.txt file is found, use it's content for genre
 			if [ -e "upecgenre.txt" ]; then
 			    Genre=$(cat "upecgenre.txt")
 			    logtext "==== Genre for this directory overwritten with $Genre from upecgenre"
 			fi
	# recursively call 
 	# check for upecignore. Scan current directory only if "upecignore.txt" is NOT found
 			if [ ! -e "upecignore.txt" ]; then
			    recursive_scan 
 			else
 			    logtext "==== ignoring Subdir $d: `cat upecignore.txt`"
 			fi
 			cd ..
		else
	# object is no directory: process as file
 	# get extension
 			filetrunc=$(echo "${d%%.*}")
#                        filetrunc=$(echo $d | sed 's/.eit//g')
 			logdebug "Filetrunc: $filetrunc"
                        eitfile="$filetrunc.eit"
 			nfofile="$filetrunc.nfo"
                        if [ -e "$eitfile" ]; then
                            logtext "==== found EIT-file:  $eitfile"
                            CurrentDir="$PWD"
# 			    Genre=$(basename "$CurrentDir")
                            Filename="$CurrentDir/""$eitfile"
 	# check for rebuild-option
 			    if [ -e "$nfofile" ] && [ $REBUILD = "y" ]; then
 				logtext "==== found NFO-file $nfofile: rebuilding"
                                parse_eit "$eitfile"
                            fi
 			    if [ ! -e "$nfofile" ]; then
 				logtext "==== NOT found NFO-File $nfofile: creating"
 				parse_eit "$eitfile"
 			    fi
 	# there is no eit-file: look for file being a video file
 			else
 			    logtext "==== EIT-file $eitfile not found! Looking for video file ===="
 			    fileext=$(echo "${d##*.}")
 			    logdebug "==== Extension: $fileext"

 			    if [[ "$VIDEOEXTENSIONS" =~ "$fileext" ]]; then
 				logdebug "Video file found"
#===================================== Heir gehts weiter:
# Video file gefunden aber kein EIT
# Analysiere den Videonamen und entferne Datum und Provider ("nackter Filename")
# Aus Datum extrahiere das Jahr 
# schreibe Metadaten:
                                logdebug "Parsing $filetrunc filebased"
                                parsevideoname "$filetrunc"
                                Title="$RETURN"
                                logdebug "Filename (Title) after normalization: $Title"
                                nfofile="$filetrunc.nfo"
                                
                                if [ -e "$nfofile" ] && [ $REBUILD = "y" ]; then
                                    logtext "==== found NFO-file $nfofile: rebuilding"
                                    parse_filebased "$filetrunc"
                                fi
                                if [ ! -e "$nfofile" ]; then
                                    logtext "==== NOT found NFO-File $nfofile: creating"
                                    parse_filebased "$filetrunc"
                                fi
 		       	    else
 				logdebug "No Video found"
 			    fi
 			fi
		fi
	done
        logtext "=== recursive scan finished! ==="
	return 0	
}
# END of recursive_scan


# ====== 
function build_XMLstring {
for tag in ${NfoFields[@]}; do
        XMLstring=$XMLstring"<"$tag">"${Nfo[$tag]}"</"$tag">" 
done
# add movie-tag
XMLstring="<movie>"$XMLstring"</movie>"
logdebug "XMLstring: $XMLstring"
}

# ====== 
function write_CSVdata {
CSVstring=""
for tag in ${CSVFields[@]}; do
        CSVstring=$CSVstring$CSVDelimiter${CSVdata[$tag]} 
done
# append to CSVfile
logdebug "Appending CSVstring: $CSVstring to §CSVFile"
echo "$CSVstring" | iconv -f ISO-8859-1 -t ASCII//TRANSLIT >> "$CSVFile"
}

# =============================
Short_Event_Descriptor() {
logdebug "==== Short_Event_Descriptor ===="
pos=$1
descriptor_byte=`dd ibs=1 skip=$((pos+1)) obs=1 count=1 if="$file" `
byte_to_int $descriptor_byte
descriptor_length=$RETURN
logdebug "Descriptor_Length: $descriptor_length"
if [ $descriptor_length -eq "0" ];
then
     descriptor_length=10
fi
event_name_byte=`dd ibs=1 skip=$((pos+5)) obs=1 count=1 if="$file"`
byte_to_int $event_name_byte
event_name_length=$RETURN
logdebug "event_name_length $event_name_length"

event_name_char=`dd ibs=1 skip=$((pos+7)) obs=1 count=$((event_name_length-1)) if="$file"`
logdebug "event_name_char $event_name_char"
Title="$event_name_char"
text_byte=`dd ibs=1 skip=$((event_name_length+pos+6)) obs=1 count=1 if="$file" `
byte_to_int $text_byte
text_length=$RETURN
logdebug "text_length $text_length"

text_char=`dd ibs=1 skip=$((event_name_length+pos+8)) obs=1 count=$((text_length-1)) if="$file" `
logdebug "text_char $text_char"
Outline="$text_char"
if [ ${#Title} -lt $MINTITLELEN ]; then
    Title="$Title""-""$Outline"
    logdebug "Including Outline ($Outline) in Title: $Title"
fi
# info2=$info2$text_char
}

# =============================
Extended_Event_Descriptor ()
{
logdebug "==== Extended_Event_Descriptor ===="
pos=$1

descriptor_byte=$(dd ibs=1 skip=$((pos+1)) obs=1 count=1 if="$file")
logdebug "Descriptor_length_raw $descriptor_byte"
byte_to_int $descriptor_byte
descriptor_length=$RETURN
logdebug "Description_Length $descriptor_length"

# reading from eit file starts after locale information (6 bytes)
item_char=`dd ibs=1 skip=$((pos+8)) obs=1 count=$((descriptor_length-6)) if="$file" `
# item_char=$(echo $item_char | sed 's// /g;s/Ä/Ae/g;s/Ö/Oe/g;s/Ü/Ue/g;s/ä/ae/g;s/ö/oe/g;s/ü/ue/g;s/ß/ss/g;')
item_char=$(echo $item_char | sed 's/[^[:print:]]/ /g;')
logdebug "item_char $item_char"
info2=$info2$item_char
logdebug "cumulative Info2: $info2"
}

# =============================
Component_Descriptor ()
{
logdebug "==== Component_Descriptor ===="
pos=$1

descriptor_length=`dd ibs=1 skip=$((pos+1)) obs=1 count=1 if="$file"`
descriptor_length=$(printf '%d' "'$descriptor_length")
if [ $descriptor_length -eq "0" ];
then
     descriptor_length=10
         fi
stream_content=`dd ibs=1 skip=$((pos+2)) obs=1 count=1 if="$file"`
stream_content=$(printf '%d' "'$stream_content")
stream_content=$((stream_content&15))
component_type=`dd ibs=1 skip=$((pos+3)) obs=1 count=1 if="$file"`
component_type=$(printf '%d' "'$component_type")

component_tag=`dd ibs=1 skip=$((pos+4)) obs=1 count=1 if="$file"`
component_tag=$(printf '%d' "'$component_tag")
text_char=`dd ibs=1 skip=$((pos+9)) obs=1 count=$((descriptor_length-7)) if="$file" `
logdebug Component_Descriptor
logdebug "Length" $descriptor_length

logdebug "Component_tag:" $component_tag
printf "s_c : %d (0x%X)\n" $stream_content $stream_content
logdebug "component_type" $component_type
logdebug "text_char" "$text_char" 
if [ $stream_content -eq 2 ];
then
eval "audio$namez=\$"text_char"" 

namez=$((namez+1))
fi
}
# =============================
Unknown_Descriptor ()
{
logdebug "==== Unknown_Descriptor ==== for $file"
pos=$1
descriptor_length=$(dd ibs=1 skip=$((posh+1)) obs=1 count=1 if="$file")
logdebug "descriptor_length raw $descriptor_length"
descriptor_length=$(printf '%d' "'$descriptor_length")
logdebug "descriptor_length calc $descriptor_length"
}


# ========================== parse_filebased ==================
# parameter: filename (without extension, normalized)
function parse_filebased ()
{
logtext "============= Processing filebased: $1 =================="
file="$1"
# important: initialize/reset global variables!
XMLstring=""

# nfo is the file extention KODI is expecting
filexml="$file.nfo"
fileraw="$file.raw"
logtext "Target XML: $filexml"

logdebug "Processing: $file"

# ============= Posting Raw ========== (just for debug)
# echo $info2 > "$fileraw"

# Posting XML
logdebug "==== XML-Fields ===="
logdebug "Title: $Title"
Outline="no outline"
logdebug "Outline: $Outline"
Plot="no Plot"
logdebug "Plot: $Plot"
logdebug "Genre: $Genre"
logdebug "===== EOF XML ======="

# Map Fields to XML-Output
NfoFields=("title" "outline" "genre" "plot")
Nfo[title]="$Title"
Nfo[outline]="$Outline"
Nfo[plot]="$Plot"
Nfo[genre]="$Genre"

# Map fields to CSV output
# CSVFields=("title" "outline" "plot" "filename") - CHANGE: moved CSV-field-enumeration to configuration part
to_printable "$Title"
CSVdata[title]="$RETURN"
to_printable "$Outline"
CSVdata[outline]="$RETURN"
to_printable "$Plot"
CSVdata[outline]="$RETURN"
to_printable "$Genre"
CSVdata[genre]="$RETURN"
to_printable "$Filename"
CSVdata[filename]="$RETURN"

# ===== producing XML ===============

logdebug "Building $filexml"

build_XMLstring
to_printable "$XMLstring"
XMLstring="$RETURN"

write_CSVdata

logdebug "XMLstring: $XMLstring"
if [ $DRYRUN == "y" ]; then
    logdebug "NOT written $filexml (DRYRUN!)"
else
    echo $XMLstring | iconv -f ISO-8859-1 -t ASCII//TRANSLIT > "$filexml"
    logdebug "written: $filexml"
fi

logdebug "Finished processing $file"

} # === END parse_filebased ====



# ========================== parse_eit ==================
# parameter: filename
function parse_eit ()
{
logtext "============= Processing $1 =================="
file="$1"
# important: initialize/reset global variables!
info2=""
XMLstring=""

# build normalized filenames
file2=$(echo "$file" | sed 's/.eit//g')
# nfo is the file extention KODI is expecting
filexml="$file2.nfo"
fileraw="$file2.raw"
logtext "Target XML: $filexml"

# check existence of infile
if [ -f "$file" ]; then
    logtext "File exists" 
else
    logtext "File not found" 
exit
fi

# Target variable for long text
info2="" 

# Offset for begin
posh=12

logdebug "Processing: $file"

namez=0
# filesize=$( stat -c %s "$file")
# filesize=$( stat --printf="%s" "$file" )
# logtext $(wc -c "$file")
filesize=0
logdebug "Filesize init: $filesize"

filesize=`wc -c <"$file"`
logdebug "Filesize calc: $filesize, Start: $posh"

logdebug "Begin Parsing"

while [ $posh -lt $filesize ]
do
    logdebug "Current position: $posh"

    descriptor=`dd ibs=1 skip=$posh obs=1 count=1 if="$file"`
    logdebug "Current position: $posh, Descriptor: $descriptor"

    logdebug "Descriptor:" $descriptor
    if [ "$descriptor" = "N" ]
    then
        Extended_Event_Descriptor $posh
    fi
    if [ "$descriptor" = "M" ]
    then
        Short_Event_Descriptor $posh
    fi
    if [ "$descriptor" = "P" ]
    then
        Component_Descriptor $posh
    fi
    posh=$((descriptor_length+posh+2))
done

logtext "Finished parsing"

logdebug "Result String info2: $info2"

# write cumulative info2 to plot
Plot=$info2

# ============= Posting Raw ========== (just for debug)
# echo $info2 > "$fileraw"

# Posting XML
logdebug "==== XML-Fields ===="
logdebug "Title: $Title"
logdebug "Outline: $Outline"
logdebug "Plot: $Plot"
logdebug "Genre: $Genre"
logdebug "===== EOF XML ======="

# Map Fields to XML-Output
NfoFields=("title" "outline" "genre" "plot")
Nfo[title]="$Title"
Nfo[outline]="$Outline"
Nfo[plot]="$Plot"
Nfo[genre]="$Genre"

# Map fields to CSV output
# CSVFields=("title" "outline" "plot" "filename") - CHANGE: moved CSV-field-enumeration to configuration part
to_printable "$Title"
CSVdata[title]="$RETURN"
to_printable "$Outline"
CSVdata[outline]="$RETURN"
to_printable "$Plot"
CSVdata[outline]="$RETURN"
to_printable "$Genre"
CSVdata[genre]="$RETURN"
to_printable "$Filename"
CSVdata[filename]="$RETURN"

# ===== producing XML ===============

logdebug "Building $filexml"

build_XMLstring

write_CSVdata

logdebug "XMLstring: $XMLstring"
if [ $DRYRUN == "y" ]; then
    logdebug "NOT written $filexml (DRYRUN!)"
else
    echo $XMLstring | iconv -f ISO-8859-1 -t ASCII//TRANSLIT > "$filexml"
    logdebug "written: $filexml"
fi

logdebug "Finished processing $file"

} # === END parse_eit ====



function to_printable {
# return value is written to global RETURN

# do charset-converion
RETURN=$(echo $1 | iconv -f ISO-8859-1 -t ASCII//TRANSLIT)

# remove remaining not printable characters
RETURN=$(echo $RETURN | sed 's/[^[:print:]]/ /g;')
logdebug $RETURN
}


# =============================
# Main
# =============================
# parameter 1: filename

logtext "================ UPEC - a ultra simple EIT Converter ======================"

# STARTDIR="/home/immanuel/Videos/Gilmore Girls Test"

cd "$VIDEOPATH"
recursive_scan


logtext "============== UPEC finished - thank you for using me! =================="


exit 0


# EOF
