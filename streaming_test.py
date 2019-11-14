#!/usr/bin/python
"""
The very first line should be the above line of code for the program to run
No blank line allowed on Line-1
"""

'''
The code is hardcoded for the network (The IP addresses are hardcoded)

the network is shown below
       
    h1-           -h2
       s1 ----- s2 
    h3-           -h4

Code needs to be written to handle a more general network

The below global variables need to be set according to the experiment

'''

import sys
import time
from threading import Thread

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import CPULimitedHost
from mininet.link import TCLink
from mininet.util import dumpNodeConnections
from mininet.log import setLogLevel
from mininet.cli import CLI

from functools import partial
from mininet.node import RemoteController
import subprocess
from os.path import isfile, join
import os

'''
Maximum of 32 hosts , working for this topology (some RAM limitations , i guess) - 
tested on a 4 GB Ubuntu 14.04 
'''
n = 4 # number of hosts

## Experiment variables

bw_options = [10.0, 3.0, 1.0] # link bandwidth in mbps (all links have the same bandwidth)
loss_options = [0, 30, 70] # link loss in percentage
#protocol_options = ['rtp', 'rtp-mts']
protocol_options = ['rtp']
#codec_options = ['h264', 'mpeg2', 'mpeg5', 'vp80']
codec_options = ['h264']
mode_options = ['seq', 'par'] # sequential or parallel

## Paths

workingDir = os.getcwd()

capture_script = join(workingDir, 'streaming_capture.sh')  # '/home/sumanth/mininetDir/capture.sh'

sd_flow_filepath = join(workingDir, 'testVideos/360x240_2mb.mp4') #'/home/sumanth/sample/360x240_2mb.mp4'
hd_flow_filepath = join(workingDir, 'testVideos/720x480_5mb.mp4') #'/home/sumanth/sample/720x480_5mb.mp4'
stream_time = 40 # wait for 40 seconds before shutting down (accomodate for the max time of a video safely)

savedStreamsDir = join(workingDir, 'savedStreams') # '/home/sumanth/teststorage/'
capturedTracesDir = join(workingDir, 'capturedTraces') # '/home/sumanth/mininetDir/capture_traces'


## Auxiliary class for running the experiments

class ExperimentConfiguration():
    def __init__(self, bw, loss, protocol, codec, mode, iteration=1):
        self.bw = bw
        self.loss = loss
        self.protocol = protocol
        self.codec = codec
        self.mode = mode
        self.iteration = iteration
    
    def __str__(self):
        return str(self.__dict__)


## Topology class

class SimpleTopo(Topo):
    global n
    # 2 switches and n hosts (n/2 hosts per switch), a link between 2 switches
    def __init__(self, **opts):
        Topo.__init__(self, **opts)

        experiment_configuration = opts.get('experiment_configuration')

        if not experiment_configuration:
            raise ValueError('> experiment_configuration must be informed to SimpleTopo! <')

        # Adding switches
        s1 = self.addSwitch('s1')
        s2 = self.addSwitch('s2')

        # 'dummy' is added to not use the zero index
        h = ['dummy'] # list of hosts


        # Adding hosts
        for i in range(n+1)[1:]:
            h.append(self.addHost('h{0}'.format(i)))
            if (i%2)==1:
                self.addLink(h[i], s1, bw=experiment_configuration.bw)
            else:
                self.addLink(h[i], s2, bw=experiment_configuration.bw)

        self.addLink(s1, s2, bw=experiment_configuration.bw, loss=experiment_configuration.loss)


## Auxiliary functions

def get_dst_vlc_command(output_filename, local_stream_time, experiment_configuration):
    if experiment_configuration.protocol == 'rtp':
        if experiment_configuration.codec == 'h264':
            return 'vlc-wrapper rtp://@:5004 --sout \
                "#transcode{vcodec=h264,acodec=mpga,ab=128,channels=2,samplerate=44100}:\
                std{access=file,mux=mp4,dst=%s}" \
                --run-time %d vlc://quit &'%(output_filename, local_stream_time)
        
        raise ValueError('> codec not recognized in get_dst_vlc_command! <')
    
    raise ValueError('> protocol not recognized in get_dst_vlc_command! <')

def get_src_vlc_command(input_filename, local_stream_time, dstIP, experiment_configuration):
    if experiment_configuration.protocol == 'rtp':
        if experiment_configuration.codec == 'h264':
            return 'vlc-wrapper -vvv %s --sout \
                #transcode{vcodec=h264,acodec=mpga,ab=128,channels=2,samplerate=44100}:\
                duplicate{dst=rtp{dst=%s,port=5004,mux=ts}}"\
                --run-time %d vlc://quit'%(input_filename, dstIP, local_stream_time)
        
        raise ValueError('> codec not recognized in get_src_vlc_command! <')
    
    raise ValueError('> protocol not recognized in get_src_vlc_command! <')

def get_capture_time():
    return stream_time + (n-2)*(stream_time/2)

def get_input_filepaths(host_pairs):
    
    input_filepaths = []
    for host_a, host_b in host_pairs:
        if host_a.name == 'h1' and host_b.name == 'h2':
            input_filepaths.append(sd_flow_filepath)
        elif host_a.name == 'h3' and host_b.name == 'h4':
            input_filepaths.append(hd_flow_filepath)
        else:
            raise ValueError('> host_pair not expected in get_input_filepaths!')

    return input_filepaths

def get_output_filepaths(host_pairs, input_filepaths, experiment_configuration):

    output_filepaths = []
    for index in range(0, len(host_pairs)):
        host_src = host_pairs[index][0]
        host_dst = host_pairs[index][1]

        input_filepath = input_filepaths[index]
        output_file = input_filepath.split('/')[-1]   # gets the actual file name, from the full path name
        output_file = output_file.split('.')[0] \
            + '_%d-mb-link'%experiment_configuration.bw \
            + '_%d-loss'%experiment_configuration.loss \
            + '_%s-to-%s'%(host_src.name, host_dst.name) \
            + '_%d-hosts'%n \
            + '_%s-protocol'%experiment_configuration.protocol \
            + '_%s-codec'%experiment_configuration.codec \
            + '_%s-mode'%experiment_configuration.mode \
            + '_%s-iteration'%experiment_configuration.iteration \
            + '.mp4'
        
        output_filepaths.append(join(savedStreamsDir, output_file))

def get_hosts(net):

    # 'dummy' is added to not use the zero index
    h = ['dummy'] # list of hosts

    # Getting hosts
    for i in range(n+1)[1:]:
        h.append(net.get('h%d'%i))
    
    return h

def get_host_pairs(net):

    h = get_hosts(net)
    
    host_pairs = [] # list of tuples
    for i in range((n/2)+1)[1:]:
        host_pairs.append(h[2*i-1],h[2*i])

    return host_pairs


## Main functions

def stream(src, dst, input_filename, output_filename, experiment_configuration):
    global stream_time
    local_stream_time = stream_time * (n/2)

    print 'Executing command on client %s <- %s'%(dst.name, src.name)
    client_command = get_dst_vlc_command(output_filename, local_stream_time, experiment_configuration)
    client_result = dst.sendCmd(client_command)
    # print client_command
    
    time.sleep(5)

    print 'Executing command on server %s -> %s'%(src.name, dst.name)
    server_command = get_src_vlc_command(input_filename, dstIP, local_stream_time)
    server_result = src.sendCmd(server_command)
    # print server_command

def initiateCapture(h, output_filepath):
    '''
    Runs a capture script to initiate wireshark capture
    wireshark capture is used to obtain stats for throughput delay
    '''

    output_filename_without_extension = output_filepath.split('/')[-1].split('.')[0]

    command = 'bash %s %s %s %d %s'%(
        capture_script, 
        capturedTracesDir, 
        output_filename_without_extension,
        get_capture_time(), 
        interface_name)

    h.cmd(command) # doesnt wait for the command to finish, if it is a blocking command

def stream_videos_in_sequence(net, host_pairs, input_filepaths, output_filepaths, experiment_configuration):
    
    for index in len(host_pairs):
        host_src = host_pairs[index][0]
        host_dst = host_pairs[index][1]

        initiateCapture(host_src, output_filepaths[index])
        initiateCapture(host_dst, output_filepaths[index])

        stream(host_src, host_dst, input_filepaths[index], output_filepaths[index], experiment_configuration)

        ## waiting for video flows to complete
        host_src.waitOutput()
        host_dst.waitOutput()
        print 'Video streaming complete from %s -> %s !!!'%(host_src.name, host_dst.name)

def stream_videos_in_parallel(net, host_pairs, input_filepaths, output_filepaths, experiment_configuration):

    for index in len(host_pairs):
        host_src = host_pairs[index][0]
        host_dst = host_pairs[index][1]

        initiateCapture(host_src, output_filepaths[index])
        initiateCapture(host_dst, output_filepaths[index])

        stream(host_src, host_dst, input_filepaths[index], output_filepaths[index], experiment_configuration)
    
    ## waiting for video flows to complete
    for host_src, host_dst in host_pairs:
        host_src.waitOutput()
        host_dst.waitOutput()
    
    print 'Parallel video streaming complete!'

def vlc_stream(net, experiment_configuration):

    host_pairs = get_host_pairs(net)
    input_filepaths = get_input_filepaths(host_pairs, experiment_configuration)
    output_filepaths = get_output_filepaths(host_pairs, input_filepaths, experiment_configuration)

    if experiment_configuration.mode == 'seq':
        stream_videos_in_sequence(net, host_pairs, input_filepaths, output_filepaths, experiment_configuration)
    elif experiment_configuration.mode == 'par':
        stream_videos_in_parallel(net, host_pairs, input_filepaths, output_filepaths, experiment_configuration)
    else:
        raise ValueError('> mode not expected in experiment_configuration at vlc_stream! <')

def run_experiment(experiment_configuration):

    print 'Creating network and running simple performance test'
    topo = SimpleTopo(experiment_configuration=experiment_configuration)
    net = Mininet(topo=topo, host=CPULimitedHost, link=TCLink, 
        controller=partial(RemoteController, ip='127.0.0.1', port=6633))

    print 'Starting the network'
    net.start()
    #applyQueues()

    print "Testing network connectivity"
    net.pingAll()

    CLI(net) # starts the mininet command line prompt

    print 'Streaming the video via VLC'
    vlc_stream(net, experiment_configuration)

    CLI(net) # starts the mininet command line prompt

    print 'Stopping the network'
    net.stop()

def start_all_experiments():

    for experiment_bw in bw_options:
        for experiment_loss in loss_options:
            for experiment_protocol in protocol_options:
                for experiment_codec in codec_options:
                    for experiment_mode in mode_options:
                        experiment_configuration = ExperimentConfiguration(
                            bw=experiment_bw, 
                            loss=experiment_loss, 
                            protocol=experiment_protocol, 
                            codec=experiment_codec, 
                            mode=experiment_mode,
                            iteration=1)
                    
                    print 'Running experiment ' + str(experiment_configuration)
                    run_experiment(experiment_configuration)

if __name__=='__main__':

    #setLogLevel('info')
    start_all_experiments()
