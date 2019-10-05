#!/bin/bash

# How often should the speedtest run? waittime in seconds.
WAITTIME=5

# How high is is the max. actual download and upload rate, without aborting the script?
DLimiter=6
ULimiter=4

# Fritz!Box Access Data
BoxIP="fritz.box" # 192.168.178.1
BoxUSER="USER" # Create a user in System > User on your Fritz!Box
BoxPW="PASSWORT"

# Test if speedtests.csv exists
if [ ! -f "speedtests.csv" ];then
	echo "Datum;Server;Ping;Download;Upload" >> speedtests.csv
fi

# Test is all needed packages are installed
which curl bc wget grep awk sed > /dev/null
if [ $? == 1 ];then
	apt update  > /dev/null
	apt install curl bc wget grep awk sed -y  > /dev/null
fi

test if speedtest-csv is installed
if [ ! -f "/usr/bin/speedtest-csv" ];then
	wget -q https://raw.githubusercontent.com/HenrikBengtsson/speedtest-cli-extras/master/bin/speedtest-csv -O /usr/bin/speedtest-csv
	chmod +x /usr/bin/speedtest-csv
fi

# grep actual download and upload rate from Fritz!Box
location="/igdupnp/control/WANCommonIFC1"
uri="urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1"
action='GetAddonInfos'
BoxData=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p")

RUNnumber=0
aborted=0

while sleep $WAITTIME; do
	clear
	echo Fritz!Box Speedometer
    echo Successful run: $RUNnumber
	echo Aborted because of too high bandwidth usage: $aborted

	DL=$(echo $BoxData | grep NewByteReceiveRate | cut -d ' ' -f 2)
	DL=$(($DL*8))
	DL=$(bc -l <<< "$DL/1000000")
	DL=$(echo $DL | cut -d '.' -f 1)

	UL=$(echo $BoxData | grep NewByteSendRate | cut -d ' ' -f 2)
	UL=$(($UL*8))
	UL=$(bc -l <<< "$UL/1000000")
	UL=$(echo $UL | cut -d '.' -f 1)

	if [[ $DL < $DLimiter && $UL < $ULimiter ]]; then
		let RUNnumber++
		speedtest-csv --sep ';'  | cut -d ';' -f 1,5,7,8,9 >> speedtests.csv
	else
		let aborted++
		echo
		echo Speedtest aborted because of too high bandwidth usage!
		echo Download: $DL MBit/s
		echo Download Limit: $DLimiter MBit/s
		echo
		echo Upload: $UL MBit/s
		echo Upload Limit: $ULimiter MBit/s
		sleep 5
	fi
done;
exit 1;
