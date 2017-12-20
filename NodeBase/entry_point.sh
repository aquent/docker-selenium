#!/bin/bash

source /opt/bin/functions.sh
/opt/bin/generate_config > /opt/selenium/config.json

export GEOMETRY="$SCREEN_WIDTH""x""$SCREEN_HEIGHT""x""$SCREEN_DEPTH"

if [ ! -e /opt/selenium/config.json ]; then
  echo No Selenium Node configuration file, the node-base image is not intended to be run directly. 1>&2
  exit 1
fi

if [ -z "$HUB_PORT_4444_TCP_ADDR" ]; then
  echo Not linked with a running Hub container 1>&2
  exit 1
fi

function shutdown {
  kill -s SIGTERM $NODE_PID
  wait $NODE_PID
}

REMOTE_HOST_PARAM=""
if [ ! -z "$REMOTE_HOST" ]; then
  echo "REMOTE_HOST variable is set, appending -remoteHost"
  REMOTE_HOST_PARAM="-remoteHost $REMOTE_HOST"
fi

if [ ! -z "$SE_OPTS" ]; then
  echo "appending selenium options: ${SE_OPTS}"
fi

SCREEN_PATH="/tmp/screen"
mkdir -p $SCREEN_PATH
SERVERNUM=$(get_server_num)

rm -f /tmp/.X*lock

xvfb-run -n $SERVERNUM --server-args="-screen 0 $GEOMETRY -ac +extension RANDR -fbdir $SCREEN_PATH" \
  bash -c "unclutter -idle 1 &
    java ${JAVA_OPTS} -Dvideo.xvfbscreen=$SCREEN_PATH \
      -cp /opt/selenium/selenium-video-node.jar:/opt/selenium/selenium-server-standalone.jar \
      org.openqa.grid.selenium.GridLauncherV3 \
      -servlets com.aimmac23.node.servlet.VideoRecordingControlServlet -proxy com.aimmac23.hub.proxy.VideoProxy \
      -role node \
      -hub http://$HUB_PORT_4444_TCP_ADDR:$HUB_PORT_4444_TCP_PORT/grid/register \
      -nodeConfig /opt/selenium/config.json \
      ${SE_OPTS}
    kill %1" &
NODE_PID=$!

trap shutdown SIGTERM SIGINT
wait $NODE_PID
