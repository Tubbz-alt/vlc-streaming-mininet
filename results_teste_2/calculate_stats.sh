
capturedTracesDir="capturedTraces"

tempFilePreffix="temp_"

declare -A ips

ips[h1]="10.0.0.1"
ips[h2]="10.0.0.2"
ips[h3]="10.0.0.3"
ips[h4}="10.0.0.4"

port="5004"

summaryFile="summary-bitrate-duration-delay.csv"

echo "Cleaning $summaryFile..."
echo "" > $summaryFile


echo "Removing previous temp files..."
rm $capturedTracesDir/$tempFilePreffix*


for trace in $capturedTracesDir/*.pcap*; do
  ## Ignores created temp files
  [[ $trace == */$tempFilePreffix* ]] && continue

  echo "FOR $trace:"

  srcToDst =$(echo $trace | grep -E -o 'h[1-4]_to_h[1-4]')

  src=$(echo $srcToDst | cut -f1 -d'_')

  dst=$(echo $srcToDst | cut -f3 -d'_')

  tshark -r $trace -Y "((ip.addr eq $ips[$src] and ip.addr eq $ips[$dst]) and (udp.port eq $port))" -w temp.pcap

  bitrate=$(capinfos -i temp.pcap | grep "Data bit rate" | grep -o -E "[0-9].+ " | cut -f1 -d' ')

# duration = capture duration = time between first and last packet
duration=$(capinfos -u temp.pcap | grep "Capture duration" | grep -o -E "[0-9]+ " | cut -f1 -d' ')

packetCount=$(capinfos -c temp.pcap | grep "Number of packets" | grep -o -E "[0-9]+ " | cut -f1 -d' ')


  filenamePreffix=$(echo $trace | cut -f2 -d'/' | cut -f1 -d'x')
#  echo "filePreffix: $filenamePreffix"

  referenceVideo=$(ls $testVideosDir/$filenamePreffix*)
#  echo "refVideo: $referenceVideo"

  streamFilename=$(echo $trace | cut -f2 -d'/')
#  echo "streamFilename: $streamFilename"

  statsFilenameNoExtension=$(echo $streamFilename | cut -f1 -d'.')
#  echo "statsFilenameNoExtension: $statsFilenameNoExtension"

  tempVideo="$tracesDir/$tempFilePreffix$streamFilename"
#  echo "tempVideo: $tempVideo"

  tempStats="$tracesDir/$tempFilePreffix$statsFilenameNoExtension-stats.log"
#  echo "tempStats: $tempStats"

  echo "Calculating SSIM... (Caution: it will overwrite output files!)"

  ffmpeg -i $trace -i $referenceVideo -y -filter_complex "ssim" "$tempVideo" &> $tempStats

  echo "Done! Parsing $tempStats..."


  ssim=$(grep -i 'parsed_ssim' $tempStats | cut -f2 -d"M")
  ssim=$(echo $ssim | xargs echo -n)
  echo "Done! SSIM: $ssim"

  echo "Appeding results to $summaryFile..."

  echo "$trace;$ssim" >> $summaryFile

  echo "SSIM saved!"

done
