#!/bin/bash
album_art=$(playerctl -p spotify metadata mpris:artUrl)
if [[ -z $album_art ]]
then
   # spotify is dead, we should die too.
   exit
fi
if [[ -f /tmp/cover.url ]]
then
   old_album_art=$(cat /tmp/cover.url)
   if [[ $old_album_art == $album_art ]]
   then
      echo "/tmp/cover.jpeg"
      exit
   fi
fi
curl -s  "${album_art}" --output "/tmp/cover.jpeg"
echo ${album_art} > /tmp/cover.url
echo "/tmp/cover.jpeg"
