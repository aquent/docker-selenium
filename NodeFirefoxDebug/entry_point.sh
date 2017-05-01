#!/bin/bash

source /opt/bin/functions.sh
/opt/selenium/generate_config > /opt/selenium/config.json

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

if [ ! -z "$REMOTE_HOST" ]; then
  >&2 echo "REMOTE_HOST variable is *DEPRECATED* in these docker containers.  Please use SE_OPTS=\"-host <host> -port <port>\" instead!"
  exit 1
fi

if [ ! -z "$SE_OPTS" ]; then
  echo "appending selenium options: ${SE_OPTS}"
fi

# TODO: Look into http://www.seleniumhq.org/docs/05_selenium_rc.jsp#browser-side-logs

SCREEN_PATH="/tmp/screen"
mkdir -p $SCREEN_PATH
SERVERNUM=$(get_server_num)

rm -f /tmp/.X*lock

env | cut -f 1 -d "=" | sort > asroot
  sudo -E -u seluser -i env | cut -f 1 -d "=" | sort > asseluser
  sudo -E -i -u seluser \
  "$(for E in $(grep -vxFf asseluser asroot); do echo $E=$(eval echo \$$E); done)" \
  DISPLAY=$DISPLAY \
  xvfb-run -n $SERVERNUM --server-args="$DISPLAY -screen 0 $GEOMETRY -ac +extension RANDR -fbdir $SCREEN_PATH" \
  bash -c "unclutter -idle 1 &
    java ${JAVA_OPTS} -Dvideo.xvfbscreen=$SCREEN_PATH \
      -cp /opt/selenium/selenium-video-node.jar:/opt/selenium/selenium-server-standalone.jar \
      org.openqa.grid.selenium.GridLauncher \
      -servlets com.aimmac23.node.servlet.VideoRecordingControlServlet -proxy com.aimmac23.hub.proxy.VideoProxy \
      -role node \
      -hub http://$HUB_PORT_4444_TCP_ADDR:$HUB_PORT_4444_TCP_PORT/grid/register \
      ${REMOTE_HOST_PARAM} \
      -nodeConfig /opt/selenium/config.json \
      ${SE_OPTS}
    kill %1" &
NODE_PID=$!

trap shutdown SIGTERM SIGINT
for i in $(seq 1 10)
do
  xdpyinfo -display $DISPLAY >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    break
  fi
  echo Waiting xvfb...
  sleep 0.5
done

fluxbox -display $DISPLAY &

x11vnc -forever -usepw -shared -rfbport 5900 -display $DISPLAY &

wait $NODE_PID
