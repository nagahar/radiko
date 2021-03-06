#!/bin/bash

date=`date '+%Y-%m-%d-%H%M'`
dir=`dirname $0`
authkey_value="bcd151073c03b352e1ef2fd66c32209da9ca0afa"

if [ $# -eq 4 ]; then
    type=$1
    channel=$2
    DURATION=`expr $3 \* 60`
    fname=${4}_${date}
    output=$dir/${fname}.mp3
    tmp=/tmp/${fname}.m4a
else
    echo "usage : $0 (nhk|radiko) channel_name minutes file_name"
    exit 1
fi

if [ "$type" = "radiko" ]; then
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

elif [ "$type" = "nhk" ]; then

    if [ "${channel}" = "r2" ]; then
        # R2
        stream_url=$(curl --silent \
        "https://www.nhk.or.jp/radio/config/config_v5.7.3_radiru_and.xml" \
            | xmllint --xpath \
        "string(/radiru_config/config[@key='url_stream_r2']/value[1]/@text)" - \
            2> /dev/null)
    else
        station_id="tokyo-r1"
        # station_id="tokyo-fm"
        # Split area and channel
        area="$(echo "${station_id}" | cut -d '-' -f 1)"
        ch="$(echo "${station_id}" | cut -d '-' -f 2)"
        stream_url=$(curl --silent \
            "https://www.nhk.or.jp/radio/config/config_v5.7.3_radiru_and.xml" \
            | xmllint --xpath \
            "string(/radiru_config/area[@id='${area}']/config[@key='url_stream_${ch}']/value[1]/@text)" \
            - 2> /dev/null)
    fi

    ffmpeg \
        -loglevel error \
        -fflags +discardcorrupt \
        -i "${stream_url}" \
        -acodec copy \
        -vn \
        -bsf:a aac_adtstoasc \
        -y \
        -t ${DURATION} \
        "${tmp}"
else
    echo "Unknown type: $type"
    exit 1
fi

ffmpeg -loglevel quiet -y -i "$tmp" -acodec libmp3lame -ab 128k "$output"

if [ $? = 0 ]; then
    rm -f "$tmp"
fi

# To upload Dropbox add@2015-09-04
$dir/Dropbox-Uploader/dropbox_uploader.sh upload $output $output

if [ $? = 0 ]; then
    rm "$output"
fi


