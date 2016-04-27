#!/bin/bash

date=`date '+%Y-%m-%d-%H%M'`
playerurl=http://radiko.jp/player/swf/player_4.1.0.00.swf
dir=`dirname $0`
playerfile=$dir/player.swf
keyfile=$dir/authkey.png

if [ $# -eq 3 ]; then
  channel=$1
  DURATION=`expr $2 \* 60`
  fname=${3}_${date}
  output=$dir/${fname}.mp3
  tmp=/tmp/$fname
else
  echo "usage : $0 channel_name duration(minuites) file_name"
  exit 1
fi

#
# get player
#
if [ -f $playerfile ]; then
  rm $playerfile
  rm $keyfile
fi
# to get playerfile
if [ ! -f $playerfile ]; then
  wget -q -O $playerfile $playerurl

  if [ $? -ne 0 ]; then
    echo "failed get player"
    exit 1
  fi
fi

#
# get keydata (need swftool)
#
if [ ! -f $keyfile ]; then
  swfextract -b 14 $playerfile -o $keyfile

  if [ ! -f $keyfile ]; then
    echo "failed get keydata"
    exit 1
  fi
fi

if [ -f auth1_fms ]; then
  rm -f auth1_fms
fi

#
# access auth1_fms
#
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_1" \
     --header="X-Radiko-App-Version: 2.0.1" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --post-data='\r\n' \
     --no-check-certificate \
     --save-headers \
     https://radiko.jp/v2/api/auth1_fms

if [ $? -ne 0 ]; then
  echo "failed auth1 process"
  exit 1
fi

#
# get partial key
#
authtoken=`perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)' auth1_fms`
offset=`perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)' auth1_fms`
length=`perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)' auth1_fms`

partialkey=`dd if=$keyfile bs=1 skip=${offset} count=${length} 2> /dev/null | base64`
echo "authtoken: ${authtoken} \noffset: ${offset} length: ${length} \npartialkey: 

$partialkey"

rm -f auth1_fms

if [ -f auth2_fms ]; then
  rm -f auth2_fms
fi

#
# access auth2_fms
#
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_1" \
     --header="X-Radiko-App-Version: 2.0.1" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --header="X-Radiko-Authtoken: ${authtoken}" \
     --header="X-Radiko-Partialkey: ${partialkey}" \
     --post-data='\r\n' \
     --no-check-certificate \
     https://radiko.jp/v2/api/auth2_fms

if [ $? -ne 0 -o ! -f auth2_fms ]; then
  echo "failed auth2 process"
  exit 1
fi

echo "authentication success"
areaid=`perl -ne 'print $1 if(/^([^,]+),/i)' auth2_fms`
echo "areaid: $areaid"

rm -f auth2_fms

#
# get stream-url
#
if [ -f ${channel}.xml ]; then
  rm -f ${channel}.xml
fi

wget -q "http://radiko.jp/v2/station/stream/${channel}.xml"

stream_url=`echo "cat /url/item[1]/text()" | xmllint --shell ${channel}.xml | tail -2 | head -1`
url_parts=(`echo ${stream_url} | perl -pe 's!^(.*)://(.*?)/(.*)/(.*?)$/!$1://$2 $3 $4!'`)

rm -f ${channel}.xml

#
# rtmpdump
#
         #-r "rtmpe://f-radiko.smartstream.ne.jp" \
         #--playpath "simul-stream.stream" \
         #--app "${channel}/_definst_" \
# Added --timeout 300(max) to avoid interruption add@2014-12-30
rtmpdump -v \
         -r ${url_parts[0]} \
         --app ${url_parts[1]} \
         --playpath ${url_parts[2]} \
         -W $playerurl \
         -C S:"" -C S:"" -C S:"" -C S:$authtoken \
         --live \
         --stop $DURATION \
         --timeout 300 \
         -o "$tmp"

ffmpeg -loglevel quiet -y -i "$tmp" -acodec libmp3lame -ab 128k "$output"
if [ $? = 0 ]; then
  rm -f "$tmp"
fi

# To upload Dropbox add@2015-09-04
$dir/Dropbox-Uploader/dropbox_uploader.sh upload $output Radios/

if [ $? = 0 ]; then
    rm "$output"
fi

