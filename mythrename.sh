#!/bin/bash
#######################################################################
#Pass in directory, filename, series name, episode name, season, episode
#create working directory if none exists
#convert file
#check series name against name in TheTVDB friendly name file
#sanatize series/episode name
#create filename
#if season/episode is 0 then create a dummy file with new filename and run filebot on it to rename
#create series directory if none exists
#create season directory if none exists
#mv the myth file to the new series/season directory
#run comskip on file and remove unwanted/extra files
#add cmd line parameter to run comskip and conversion
#######################################################################

#USAGE:######################
# This Script shall be called as a MythTV user job like as follows:
# /usr/local/bin/mythrename.sh "%DIR%" "%FILE%" "%CHANID%" "%STARTTIMEUTC%" "%TITLE%" "%SUBTITLE%" "%CATEGORY%" "%SEASON%" "%EPISODE%" "%ORIGINALAIRDATE%"
#############################

########REQUIREMENTS#########
#############################
# You need to have the following programs installed:
# handbrake with dependencies: http://www.handbrake.fr/
# filebot with dependencies: http://www.filebot.net/
#############################

######SOME CONSTANSTS FOR USER EDITING######
############################################
logdir="/home/todd/.mythrename/log" #change to your needs for logs
tempdir="/home/todd/.mythrename"
errormail="flahercc@gmail.com" # this email address will be informed in case of errors
outdir="/media/hoth/tv" # specify directory where you want the transcoded file to be placed
fbtempdir="/media/hoth/tv/.fbtemp"
sanitize="Enabled" # if set to true, sed will sanitize some of the parameters. Enabled|Disabled
comskip="Enabled" # Run comskip over the file. Enabled|Disabled
owner=todd

#######CONVERSION SETTINGS##############
########################################
convert="Disabled" #Convert the recording to save space. Enabled|Disabled
tune="film"
nicevalue=0
profile="high"
level=41
videocodec="libx264"
preset="faster"
deinterlace=1
audiocodec="copy"
threads=2

######CHECK FOR LOG########
######DIRECTORY FIRST!#####
if [ ! -d "$tempdir" ]; then
  echo "Creating the temp directory" >>"$logfile"
  mkdir "$tempdir"
  chown $owner:$owner "$tempdir"
  chmod a+rw "$tempdir"
fi

if [ ! -d "$logdir" ]; then
  echo "Creating the log directory" >>"$logfile"
  mkdir "$logdir"
  chown $owner:$owner "$logdir"
  chmod a+rw "$logdir"
fi

if [ ! -d "$fbtempdir" ]; then
  echo "Creating the filebot temp directory" >>"$logfile"
  mkdir "$fbtempdir"
  chown $owner:$owner "$fbtempdir"
  chmod a+rw "$fbtempdir"
fi

starttime=$(date +%F-%H%M%S)
echo "Script starting at $starttime"
mythrecordingsdir="$1" # specify directory where MythTV stores its recordings
file="$2"
# using sed to sanitize the variables to avoid problematic file names, only alphanumerical, space, hyphen and underscore allowed, other characters are transformed to underscore
titlepre="$5"
if [ sanitize == "Enabled" ]
  then
  subtitle="$(echo "$6" | sed 's/[^A-Za-z0-9_ -]/_/g')"
  title="$(echo "$5" | sed 's/[^A-Za-z0-9_ -]/_/g')"
  category="$(echo "$7" | sed 's/[^A-Za-z0-9_ -]/_/g')"
  season="$(echo "$8" | sed 's/[^A-Za-z0-9_ -]/_/g')"
  episode="$(echo "$9" | sed 's/[^A-Za-z0-9_ -]/_/g')"
  else
  subtitle="$(echo "$6" | sed 's:/:_:g')"
  title="$(echo "$5" | sed 's:/:_:g')"
  category="$(echo "$7" | sed 's:/:_:g')"
  season="$(echo "$8" | sed 's:/:_:g')"
  episode="$(echo "$9" | sed 's:/:_:g')"
fi

originalairdate="${10}"
chanid="$3"
starttime="$4"

if [ -z "$category" ]; then
  category="Unknown" #name for unknown category
fi

logfile="$logdir/$starttime-$title.log"
touch "$logfile"
chown $owner:$owner "$logfile"
chmod a+rw "$logfile"

echo "######PARAMETERS PASSED TO SCRIPT######" >>"$logfile"
echo "mythrename.sh $1,$2,$3,$4,$5,$6,$7,$8,$9,${10}" >>"$logfile"
echo "#######################################" >>"$logfile"

#If no subtitle, put the original air date in the subtitle field.
if [ -z "$subtitle" ]; then
  echo "No subtitle detected; using generic subtitle" >>"$logfile"
  subtitle="$originalairdate"
fi

#check if there is an alternate name for series
if [ -f "$tempdir"/thetvdbname.txt ] && [ "$title" != "" ]; then 
  echo "Looking for alternate show name for $title" >>"$logfile"
  altname=`grep "$title = " "$tempdir/thetvdbname.txt"| sed s/"$title = "/""/g `
  if [ "$altname" != "" ]; then 
    title="$altname"
    echo "TheTVDB alternate name for the show is $title" >>"$logfile"
  fi
fi

#check if series directory exists; if not create it
seriesdir="$outdir/$title"
echo "Series directory is $outdir/$title" >>"$logfile"
if [ ! -d "$seriesdir" ]; then
  echo "Making series directory for $title" >>"$logfile"
  mkdir "$seriesdir"
  chown $owner:$owner "$seriesdir"
  chmod a+rw "$seriesdir"
fi

#check if season directory exists; if not create it only if season is not 0
if [ "$season" != 0 ]; then
  seasondir="$outdir/$title/Season $season"
  if [ ! -d "$seasondir" ]; then
    echo "Creating season directory for $title" >>"$logfile"
    mkdir "$seasondir"
    chown mythtv:mythtv "$seasondir"
    chmod a+rw "$seasondir"
  fi
else
  echo "No season number detected; making season folder same as series folder" >>"$logfile"
  seasondir="$outdir/$title"
fi
echo "Season directory is $seasondir" >>"$logfile"

#check if there is season and episode information
sxe="$8x$9"
filename="$title - $sxe - $subtitle.ts" # can be customized
if [ -f "$seasondir/$filename" ]; then
  # do not overwrite outfile, if already exists, change name
  filename="$title - $sxe - $subtitle - $starttime.ts"
fi
echo "***FILENAME is $filename***" >>"$logfile"

#move $file to series/episode directory and create symlink
cp "$mythrecordingsdir/$file" "$seasondir/$filename"
echo "Copying $filename to $seasondir" >>"$logfile"
chown $owner:$owner "$seasondir/$filename"
chmod a+rw "$seasondir/$filename" #set it so anyone can delete the file (for plex/kodi)

#run file through filebot
if [ "$sxe" = "0x0" ]; then
  sxe=""
  echo "sxe is blank, running episode through filebot" >>"$logfile"
  mv "$seasondir/$filename" "$fbtempdir/$filename"
  filebot -rename "$fbtempdir/$filename" --db TheTVDB -non-strict >>"$logfile"
fi
#Move the newly named file back to the series directory
for file in $fbtempdir/*; do
  echo "The path is $file"  
  echo "The fielname is ${file##*/}"
  filename=${file##*/}
  mv "$fbtempdir/$filename" "$seasondir/$filename"
done

#convert the file if enabled
if [ $convert == "Enabled" ]; then
  conversionstarttime=$(date +%F-%H%M%S)
  echo "Starting avconv at $conversionstarttime..." >>"$logfile"
  echo "User running script is $(whoami)..." >>"$logfile"
  echo "Converting $filename..." >>"$logfile"
  echo "nice -n $nicevalue avconv -v 16 -i $seasondir/$filename -c:v $videocodec -preset $preset -tune $tune -vf yadif -profile:v $profile -level $level -c:a $audiocodec -threads $threads $seasondir/$filename.mkv" >>$logfile
  nice -n "$nicevalue" avconv -v 16 -i "$seasondir/$filename" -c:v "$videocodec" -preset "$preset" -tune "$tune" -vf yadif -profile:v "$profile" -level "$level" -c:a "$audiocodec" -threads "$threads" "$seasondir/$filename.mkv"
  # check if the transcode exited with an error; if not, delete the intermediate MPEG file and map
  if [ $? != 0 ]; then
    echo "Error occurred running avconv: input=$seasondir/$filename output=$seasondir/$filename.mkv" >>"$logfile"
  else
    conversionendtime=$(date +%F-%H%M%S)
    echo "Transcoding complete at $conversionendtime!" >>"$logfile"
    #rename the *.mpg file to *.mpg.old
  fi
  echo "" >>"$logfile"
fi

#run comskip
if [ $comskip == "Enabled" ]; then
  echo "Running comskip on $seasondir/$filename" >>"$logfile"
  wine "/home/todd/comskip/comskip.exe" "$seasondir/$filename" > /dev/null 2>&1
  
  basename=${filename%.*}
  echo "basename is $basename"  

  #change the comskip file to frame 0 so kodi will skip the first commercial break
  sed -i -e '3s/^1\t/0\t/g' "$seasondir/$basename.txt"
  
  #backup the edl file
  mv "$seasondir/$basename.edl" "$seasondir/$basename.edl.bak"  

  #delete the unneeded files
  rm "$seasondir/$basename.logo.txt"
  rm "$seasondir/$basename.log"
fi

endtime=$(date +%F-%H%M%S)
echo "Script finished at $endtime" >>"$logfile"
echo "" >> "$logfile"
