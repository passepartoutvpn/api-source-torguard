#!/bin/bash
URL="https://torguard.net/network/"
TPL="template"
SERVERS_DST="$TPL/servers.html"

mkdir -p $TPL
if ! curl -L $URL >$SERVERS_DST.tmp; then
    exit
fi
mv $SERVERS_DST.tmp $SERVERS_DST
