#!/bin/sh
#
# makes use of bash string and substring maniulation functions, for details
# http://tldp.org/LDP/abs/html/string-manipulation.html
#
# /storage/.xbmc/addons/service.downloadmanager.rTorrent/bin/complete.sh

config=/var/config/rtorrent.conf
outfile=/storage/complete.out

if [ ! -f $config ];then
   echo "Could not find config file $config"
   echo "exiting..."
   exit 1
fi

if [ "$#" -lt 1 ] 
then
   echo "Need input"
   echo "Exiting..."
   exit 1
fi

# Load config.
. $config

# Load vars.
echo " " >> $outfile
echo "`date` parms=$@" >> $outfile
HASH=$1
shift

FROM="$@"
# $FROM 5BC2A1A92F7A79227C4D5BBE270BE3F33671E500 /storage/downloads/TVshows/Suits.S04E02.HDTV.x264-LOL.[VTV].mp4

# remove any trailing slash
FROM="${FROM%/}"
# $FROM 5BC2A1A92F7A79227C4D5BBE270BE3F33671E500 /storage/downloads/TVshows/Suits.S04E02.HDTV.x264-LOL.[VTV].mp4

# Remove from left longest string ending in slash (leaves filename)
NAME=${FROM##*/}
# $NAME Suits.S04E02.HDTV.x264-LOL.[VTV].mp4

# Do we have a MATCH
MATCH=${FROM%/*}
# $MATCH 5BC2A1A92F7A79227C4D5BBE270BE3F33671E500 /storage/downloads/TVshows
MATCH=${MATCH##*/}
# $MATCH TVshows
echo "FROM=$FROM*MATCH=$MATCH*NAME=$NAME*" >> $outfile

# Do we have a watch dir match, if do use it.
for RTORRENT_DIR in ${RTORRENT_DIRS//,/ } ;do
   if [[ "$MATCH" == "$RTORRENT_DIR" ]];then
      STORE=${RTORRENT_COMPLETE_DIR}${RTORRENT_DIR}
      echo "Watchdir matched - STORE=$STORE*" >> $outfile
   fi
done

# if we dont have a watch dir match use the rutorrent label
if [ -z "$STORE" ] ;then
   RTORRENT_DIR=$(xmlrpc2scgi.py -p 'scgi://localhost:5000' d.get_custom1 $HASH |sed 's/%20/ /g;s/%2F/\//g')
   if [ "$RTORRENT_DIR" ];then
      STORE=${RTORRENT_COMPLETE_DIR}${RTORRENT_DIR}
      echo "Using label - STORE=$STORE*" >> $outfile
   fi
fi

# Do on complete action if we have STORE var here and
# RTORRENT_ON_COMPLETE is Move or Link, else do nothing.
if [ "$STORE" ] ;then
   if [ "$RTORRENT_SORT_SERIES" == "true" ];then
      # Make sure series are in a dir with series.name.sNN, if possible.
      echo $NAME |grep -qi s[0-9][0-9]
      if [ "$?" -eq "0" ];then
          SHOW=${NAME%.[s,S][0-9][0-9]*}
          SHOW=$(echo $SHOW | tr '.' ' ')
          SHOW=$(echo $SHOW |tr '[A-Z]' '[a-z]')
	  echo "series.name.sNN SHOW=$SHOW*" >> $outfile
          STORE="$STORE/$SHOW"
      fi
      # Make sure series are in a dir with series.name.NxNN, if possible.
      echo $NAME |grep -qi [0-9]x[0-9][0-9]
      if [ "$?" -eq "0" ];then
          SHOW=${NAME%.[0-9][x,X][0-9][0-9]*}
          SHOW=$(echo $SHOW | tr '.' ' ')
          SHOW=$(echo $SHOW |tr '[A-Z]' '[a-z]')
	  echo "series.name.NxNN SHOW=$SHOW*" >> $outfile
          STORE="$STORE/$SHOW"
      fi
      echo "Final STORE=$STORE*" >> $outfile
   fi

   # Should we run complete action if so run it.
   if [ $RTORRENT_ON_COMPLETE == Move ] ;then
      mkdir -p "$STORE"
      xmlrpc2scgi.py -p 'scgi://localhost:5000' d.set_directory $HASH "$STORE"
      mv "$FROM" "$STORE"
   elif [ $RTORRENT_ON_COMPLETE == Link ] ;then
      mkdir -p "$STORE"
      ln -sf "$FROM" "$STORE"
   fi
fi

# Notify xbmc user
xbmc-send -a "Notification(rTorrent - Download Completed,$NAME,10000)"
