#!/bin/bash

date=`date '+%Y-%m-%d-%H%M'`
dir=`dirname $0`
authkey_value="bcd151073c03b352e1ef2fd66c32209da9ca0afa"

if [ $# -eq 3 ]; then
  channel=$1
  DURATION=`expr $2 \* 60`
  fname=${3}_${date}
  output=$dir/${fname}.mp3
  tmp=/tmp/${fname}.m4a
else
  echo "usage : $0 channel_name duration(minuites) file_name"
  exit 1
fi

#
# access auth1_fms
#
wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_html5" \
     --header="X-Radiko-App-Version: 4.0.0" \
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

partialkey=`echo $authkey_value | dd bs=1 skip=${offset} count=${length} 2> /dev/null | base64`
echo "authtoken: ${authtoken} 
offset: ${offset}
length: ${length}
partialkey: 
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
     --header="X-Radiko-App: pc_html5" \
     --header="X-Radiko-App-Version: 4.0.0" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --header="X-Radiko-AuthToken: ${authtoken}" \
     --header="X-Radiko-PartialKey: ${partialkey}" \
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

wget -q "http://radiko.jp/v2/station/stream_smh_multi/${channel}.xml"

stream_url=`xmllint --xpath "/urls/url[@areafree='0'][1]/playlist_create_url/text()" ${channel}.xml`
rm -f ${channel}.xml

# modify ffmpeg options with HLS add@2021-01-16
ffmpeg \
    -loglevel error \
    -fflags +discardcorrupt \
    -headers "X-Radiko-Authtoken: ${authtoken}" \
    -i "${stream_url}" \
    -acodec copy \
    -vn \
    -bsf:a aac_adtstoasc \
    -y \
    -t ${DURATION} \
    "$tmp"

ffmpeg -loglevel quiet -y -i "$tmp" -acodec libmp3lame -ab 128k "$output"

if [ $? = 0 ]; then
  rm -f "$tmp"
fi

# To upload Dropbox add@2015-09-04
$dir/Dropbox-Uploader/dropbox_uploader.sh upload $output $output

if [ $? = 0 ]; then
    rm "$output"
fi

