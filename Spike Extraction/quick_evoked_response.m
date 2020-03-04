function fig = quick_evoked_response( pathname, filename)
%
% This script is hijacked from the frontiers project to do quick spike 
% extraction. It doesn't clean, it does't check for errors or any
% of other synchronization bullshit. It just takes an h5 file, gets the
% filtered trace and gets some basic spikes with their waveform shapes
%
% The goal of this script is to give you an objective
% estimate quickly of whether you're recording in the right area. It's best
% for a couple of minutes of sedated or passive recording, but nothing 
% like complicated behavior.
%
% Note that because multichannel systems is so shit at building things, we
% can't get the same rate from the summary file (or maybe I'm missing
% something and it's me who's shit) so, if you care about timiing, maybe
% check that the assumed values here give reasonable results and adjust
% accordingly
%
% Created on 13 March 2019 by Stephen Town
% Modifed from show_me_the_spikes.m on 20 March 2019
%
% Enable library
% addpath('C:\Users\Dumbo\Documents\MATLAB\Optional Toolboxes\McsMatlabDataTools')

try

    % Request file by user
    if nargin == 0
        [filename, pathname] = uigetfile('*.h5');
    end
   
    % ASSUMPTION
    fS = 2e4;
    
    % Load data 
    H5 = McsHDF5.McsData( fullfile( pathname, filename) );
    
    % Get digital events
    digEv = get_MCS_digital_events_obj(H5, 'Digital Events3');
    
    if isempty(digEv)
        error('Could not find digital events')
    end
    
%     figure; ax = axes('NextPlot','Add'); 
%     digEv.plot % Plot digital data
    dig_times = double(digEv.Events{1}(1,:)) ./ 1e6;
    
    % Load the data
    fltObj = get_MCS_analog_obj( H5, 'Filter Data1');
    fltData = fltObj.ChannelData;
    [nChans, ~] = size(fltData);           
         
    % Create figures   
    fig = figureST( ['Evoked Response?: ' filename]);
    sp = dealSubplots(4, nChans/4);
    xlabel(sp(end,1),'Time (s)')
    ylabel(sp(end,1),'Firing Rate')
    
    % PSTH properties
    bin_width = 0.01;
    psth_edges = -0.3 : bin_width : 0.3;
    psth_centers = edges2centers( psth_edges);
    
    % For each channel
    for chan = 1 : nChans
                    
        % Get spike times (returns in MCS Samples)
        [spike_samps, ~] = getSpikeTimes(fltData(chan,:));
        spike_times = spike_samps ./ fS;
        
        if numel(spike_times) < 2, continue; end
        
        % Get PSTH
        taso = bsxfun(@minus, spike_times, dig_times);
        nHist = histc( taso, psth_edges);
        nHist = transpose( nHist(1:end-1,:));
        nHist = nHist ./ bin_width; % Count to rate conversion
        
        % Plot data
        plotSE_patch( psth_centers, nHist, 'x', sp(chan), 'b');
      
        % Label axes 
        title(sp(chan), sprintf('C%02d', chan))
    end        

catch err
    err
    keyboard
end




