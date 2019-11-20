#!/usr/bin/env bash

## Config

capturedTracesDir="capturedTraces"

tempFilePreffix="temp_"

declare -A ips

ips[h1]="10.0.0.1"
ips[h2]="10.0.0.2"
ips[h3]="10.0.0.3"
ips[h4]="10.0.0.4"

port="5004"

summaryFile="summary-bitrate-duration-delay.csv"



echo "Preparing $summaryFile..."
echo "captured_trace;bitrate;duration;packet_count;delay" > $summaryFile


echo "Removing previous temp files..."
rm $capturedTracesDir/$tempFilePreffix*


for trace in $capturedTracesDir/*.pcap*; do
  ## Ignores created temp files
  [[ $trace == */$tempFilePreffix* ]] && continue

  echo "FOR $trace:"

  srcToDst=$(echo $trace | grep -E -o 'h[1-4]_to_h[1-4]')
#  echo $srcToDst

  src=$(echo $srcToDst | cut -f1 -d'_')
#  echo $src

  dst=$(echo $srcToDst | cut -f3 -d'_')
#  echo $dst  

  traceFilename=$(echo $trace | cut -f2 -d'/')
#  echo "traceFilename: $traceFilename"

  traceFilenameNoExtension=$(echo $traceFilename | cut -f1 -d'.')
#  echo "traceFilenameNoExtension: $traceFilenameNoExtension"

  tempTrace="$capturedTracesDir/$tempFilePreffix$traceFilenameNoExtension-filtered.pcap"
  echo "tempTrace: $tempTrace"


  echo "Filtering TCP packets sent from ${ips[$src]} to ${ips[$dst]}..."
  sudo tshark -r $trace -Y "((ip.addr eq ${ips[$src]} and ip.addr eq ${ips[$dst]}) and (tcp.port eq 8080))" -w $tempTrace

#  echo "Filtering UDP packets sent from ${ips[$src]} to ${ips[$dst]}..."
#  sudo tshark -r $trace -Y "((ip.addr eq ${ips[$src]} and ip.addr eq ${ips[$dst]}) and (udp.port eq $port))" -w $tempTrace

  echo "Parsing temp trace..."

  bitrateInKbps=$(capinfos -i $tempTrace | grep "Data bit rate" | grep -o -E "[0-9.,]+" | cut -f1 -d' ')
#  echo $bitrateInKbps
  bitrateInKbps=$(echo ${bitrateInKbps//,})
  echo "bitrateInKbps: $bitrateInKbps"

  durationInSec=$(capinfos -u $tempTrace | grep "Capture duration" | grep -o -E "[0-9.,]+" | cut -f1 -d' ')
#  echo $durationInSec
  durationInSec=$(echo ${durationInSec//,})
  echo "durationInSec: $durationInSec"

  packetCount=$(capinfos -c $tempTrace | grep "Number of packets" | grep -o -E "[0-9,]+" | cut -f1 -d' ')
#  echo $packetCount
  packetCount=$(echo ${packetCount//,})
  echo "packetCount: $packetCount"

  packetDelayInSec=$(echo "$durationInSec*1000/$packetCount" | bc -l)
  echo "packetDelayInSec: $packetDelayInSec"

  echo "Done!"


  echo "Appeding results to $summaryFile..."

  echo "$trace;$bitrateInKbps;$durationInSec;$packetCount;$packetDelayInSec" >> $summaryFile

  echo "Stats saved!"

done

echo "Removing temp files..."
rm $capturedTracesDir/$tempFilePreffix*

