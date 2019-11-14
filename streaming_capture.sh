# $1 is the output folder to write the capture to (.pcap)
# $2 is the output filename, without extension
# $3 is the stream capture time
# $4 is the interface name

rm $1$2
touch $1$2
chmod a+w $1$2
sudo tshark -i $4 -a duration:$3 -w $1/$2 1> /tmp/streaming_test/$2_$4_output.log 2> /tmp/streaming_test/$2_$4_errors.log &