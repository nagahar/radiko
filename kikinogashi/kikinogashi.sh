#!/bin/bash

# 聴き逃し番組のURL
urls=(https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_57a5376c18f7e42420d7013ea2538882.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_a0592e806f50685382574fa68309560e.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_2464efbe2b02fcd57ba96de0cd1a63ce.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_ebbe53fe5ec234dbe175ce4670f97087.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_548efe65c19dfc115a6e1649d3fa31c7.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_a6d49facb38e08a4f3e349c5f82307e5.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_1b54c5c151415575289b7e6e7c2c05bb.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_0795b982954a9518500cab6b67d73628.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_96cee68e95b8e9fefbdd94284d5908e6.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_0513c07cab6494ed50f86df143cf5755.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_91bcd741c89e1b4dd50e56066efac762.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_16e4d41eaf69f4020336a947618d195a.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_466f54dfc54877235593b10ee6a3dcfc.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_e3585777d9d5ebdb073ad03cf8087d80.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_22a7a69448645efce641dbfe35dc8739.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_78714fe49bc6a7246bca45dcd2b24b3a.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_efd4e82b484ddd8823cab1ea2500784e.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_fce8737f14f3bb552183d14f6b87eb8d.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_fd5554526ee1e2687b5d5bd5fa3aaced.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_996c2c6cb07687477cb176c77bba4b8c.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_48adfd76a37e31f5c0e3e39bf78f0ecf.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_b1fd135fbc3c29ad01fb6842b10c419b.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_a2bc6e110ff1f0c59aab8fe278465abc.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_c207b3ac7427f77cd4eb9c704a80d22c.mp4/master.m3u8 \
    https://nhks-vh.akamaihd.net/i/radioondemand/r/971/s/stream_971_304540f09ae015fb5c20c142427283af.mp4/master.m3u8
)

name=chijin
DURATION=`expr 15 \* 60`
dir=`dirname $0`
count=0
for stream_url in ${urls[@]}
do
    count=`expr $count + 1`
    fname=${name}_${count}
    tmp=./${fname}.m4a
    output=$dir/${fname}.mp3

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

    ffmpeg -loglevel quiet -y -i "$tmp" -acodec libmp3lame -ab 128k "$output"

    if [ $? = 0 ]; then
        rm -f "$tmp"
    fi

    ../Dropbox-Uploader/dropbox_uploader.sh upload $output $output
    if [ $? = 0 ]; then
        rm "$output"
    fi

done

