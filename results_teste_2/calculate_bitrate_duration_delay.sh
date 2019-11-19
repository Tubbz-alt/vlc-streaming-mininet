#!/usr/bin/env bash

## Config

capturedTracesDir="capturedTraces"

tempFilePreffix="temp_"

declare -A ips

ips[h1]="10.0.0.1"
ips[h2]="10.0.0.2"
ips[h3]="10.0.0.3"
ips[h4}="10.0.0.4"

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

  srcToDst =$(echo $trace | grep -E -o 'h[1-4]_to_h[1-4]')
  echo $srcToDst

  src=$(echo $srcToDst | cut -f1 -d'_')
  echo $src

  dst=$(echo $srcToDst | cut -f3 -d'_')
  echo $dst  

  # traceFilename=$(echo $trace | cut -f2 -d'/')
  # echo "traceFilename: $traceFilename"

  # traceFilenameNoExtension=$(echo $traceFilename | cut -f1 -d'.')
  # echo "traceFilenameNoExtension: $traceFilenameNoExtension"

  # tempTrace="$tracesDir/$tempFilePreffix$traceFilenameNoExtension-filtered.pcap"
  # echo "tempTrace: $tempTrace"

  # echo "Creating temp trace from raw trace..."

  # tshark -r $trace -Y "((ip.addr eq $ips[$src] and ip.addr eq $ips[$dst]) and (udp.port eq $port))" -w temp.pcap

  # echo "Parsing temp trace..."

  # bitrate=$(capinfos -i temp.pcap | grep "Data bit rate" | grep -o -E "[0-9].+ " | cut -f1 -d' ')
  # echo "bitrate: $bitrate"
  
  # duration=$(capinfos -u temp.pcap | grep "Capture duration" | grep -o -E "[0-9]+ " | cut -f1 -d' ')
  # echo "duration: $duration"

  # packetCount=$(capinfos -c temp.pcap | grep "Number of packets" | grep -o -E "[0-9]+ " | cut -f1 -d' ')
  # echo "packetCount: $packetCount"

  # packetDelay=$(echo "$duration*1000/$packetCount" | bc -l)
  # echo packetDelay: $packetDelay"

  echo "Done!"


  echo "Appeding results to $summaryFile..."

  echo "$trace;$bitrate;$duration;$packetCount;$packetDelay" >> $summaryFile

  echo "Stats saved!"

done
