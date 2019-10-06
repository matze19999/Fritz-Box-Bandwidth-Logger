#!/bin/bash

# Fritz!Box Bandwidth Logger

# Written by
# Matthias Pröll <proell.matthias@gmail.com>
# Last edit: 2019/10/06

# Variables
# How often should the speedtest run? waittime in seconds.
WAITTIME=5

# How high is is the max. actual download and upload rate, without aborting the script?
DLimiter=6
ULimiter=4

# Fritz!Box Access Data
BoxIP="fritz.box" # usually 192.168.178.1

# Max number of entrys in speedtests.csv before it will be deleted
MAXCSVLINES=1000



# DONT TOUCH
RUNnumber=0
aborted=0
ERROR=0
PWD=`"pwd"`

# Functions

function convert() {
        local number=$1
		number=$(($number*8))
		number=$(bc -l <<< "$number/1000000")
		number=$(echo $number | cut -d '.' -f 1)
		echo $number
}

# Test is all needed packages are installed
which curl bc wget grep awk sed > /dev/null
if [ $? == 1 ];then
	apt update  > /dev/null
	apt install curl bc wget grep awk sed -y  > /dev/null
fi

# Test if speedtest-csv is installed
if [ ! -f "/usr/bin/speedtest-csv" ];then
	wget -q https://raw.githubusercontent.com/HenrikBengtsson/speedtest-cli-extras/master/bin/speedtest-csv -O /usr/bin/speedtest-csv
	chmod +x /usr/bin/speedtest-csv
fi

# grep actual download and upload rate from Fritz!Box
location="/igdupnp/control/WANCommonIFC1"
uri="urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1"
action='GetAddonInfos'
BoxData=`curl -s -k -m 5 --anyauth  http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p"`

if [ -z "$BoxData" ];then
		date=`date "+%Y-%m-%d %H:%M%S"`
		echo "Fritz!Box not reachable at $date" >> speedtests.csv
		ERROR=1	
		echo "Fritz!Box not reachable!"
		exit 1;
	fi


while sleep $WAITTIME; do
	# Test if speedtests.csv exists
	if [ ! -f "speedtests.csv" ];then
		echo "Date;Server;Ping;Download;Upload" >> speedtests.csv
	fi

	clear
	echo Fritz!Box Speedometer
  	echo Successful run: $RUNnumber
	echo Aborted because of too high bandwidth usage: $aborted

	DL=`echo $BoxData | grep NewByteReceiveRate | cut -d ' ' -f 2`
	UL=`echo $BoxData | grep NewByteSendRate | cut -d ' ' -f 2`
	if [ -z "$DL" ];then
		date=`date "+%Y-%m-%d %H:%M%S"`
		echo "No Internet Connection at $date" >> speedtests.csv
		ERROR=1
		echo "No Internet Connection!"
		let RUNnumber++
	fi

	DL=$(convert $DL)
	UL=$(convert $UL)

	if [[ $DL < $DLimiter && $UL < $ULimiter ]]; then
		let RUNnumber++
		speedtest-csv --sep ';'  | cut -d ';' -f 1,5,7,8,9 >> speedtests.csv
		echo Speedtest is running....
		result=`speedtest-csv --sep ';'  | cut -d ';' -f 1,5,7,8,9`
		if [ $? == 1 ]; then
			date=`date "+%Y-%m-%d %H:%M%S"`
			echo No Internet Connection at $date >> speedtests.csv
		else
			echo $result >> speedtests.csv
		fi
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

	# Check how many lines the speedtests.csv file has
	CSVLINES=`wc -l $PWD/speedtests.csv | cut -d ' ' -f 1`
	if [ "$MAXCSVLINES" -lt "$CSVLINES" ];then
		rm -f "$PWD/speedtests.csv"
	fi
done;
exit 1;
