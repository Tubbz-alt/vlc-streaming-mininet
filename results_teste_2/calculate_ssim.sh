#!/usr/bin/env bash

## Config

testVideosDir="../testVideos"

savedStreamsDir="savedStreams"

tempFilePreffix="temp_"

summaryFile="summary-stats.csv"



echo "Cleaning $summaryFile..."

echo "" > $summaryFile


echo "Removing previous SSIM temp files..."

rm $savedStreamsDir/$tempFilePreffix*


for savedStream in $savedStreamsDir/*.mp4; do
  ## Ignores created temp files
  [[ $savedStream == */$tempFilePreffix* ]] && continue

  echo "FOR $savedStream:"

  filenamePreffix=$(echo $savedStream | cut -f2 -d'/' | cut -f1 -d'x')
#  echo "filePreffix: $filenamePreffix"

  referenceVideo=$(ls $testVideosDir/$filenamePreffix*)
#  echo "refVideo: $referenceVideo"

  streamFilename=$(echo $savedStream | cut -f2 -d'/')
#  echo "streamFilename: $streamFilename"

  statsFilenameNoExtension=$(echo $streamFilename | cut -f1 -d'.')
#  echo "statsFilenameNoExtension: $statsFilenameNoExtension"

  tempVideo="$savedStreamsDir/$tempFilePreffix$streamFilename"
#  echo "tempVideo: $tempVideo"

  tempStats="$savedStreamsDir/$tempFilePreffix$statsFilenameNoExtension-stats.log"
#  echo "tempStats: $tempStats"

  echo "Calculating SSIM... (Caution: it will overwrite output files!)"

  ffmpeg -i $savedStream -i $referenceVideo -y -filter_complex "ssim" "$tempVideo" &> $tempStats

  echo "Done! Parsing $tempStats..."


  ssim=$(grep -i 'parsed_ssim' $tempStats | cut -f2 -d"M") # extract

  ssim=$(echo $ssim | xargs echo -n) # trim

  echo "Done! SSIM: $ssim"


  echo "Appeding results to $summaryFile..."

  echo "$savedStream;$ssim" >> $summaryFile

  echo "SSIM saved!"

done
