# $1 is the output folder to write the capture to (.pcap)
# $2 is the output filename, without extension
# $3 is the stream capture time
# $4 is the interface name

rm $1/$2_$4.pcap
touch $1/$2_$4.pcap
chmod a+w $1/$2_$4.pcap
sudo tshark -i $4 -a duration:$3 -w $1/$2_$4.pcap 1> /tmp/capture-$2_$4_output.log 2> /tmp/capture-$2_$4_errors.log &
