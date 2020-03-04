function H5_to_PSTH(file_path, file_name)
%
%
% Branched, 31 Jan 2020 by Stephen Town
%
% Designed primarily for quick assessment of event related responses,
% particularly for click responses with short duration
%
% Enable library
% addpath('C:\Users\Dumbo\Documents\MATLAB\Optional Toolboxes\McsMatlabDataTools')

try
           
    % Define folders and drawing options   
    if nargin == 0
        [file_name, file_path] = uigetfile('*.h5', 'Select file');
    end
    
    draw = struct('waveform', true,...
                  'times',  false,...
                  'psth',   true,...
                  'fra',    true);
                         
    bin_width = 0.01;
    psth_bins = -0.1 : bin_width : 0.4;
       
%     % Load event times
%     H5 = McsHDF5.McsData( fullfile( file_path, file_name) );
%     stim_obj = get_MCS_digital_events_obj(H5, 'Digital Events2');
%     stim_times = stim_obj.Events{1}(1,:) ./ 1e6; 
%     stim_times = double(stim_times');
%     fprintf('%d stimuli\n', numel(stim_times))
        
    % Get spike times               
    [spike_times, chan_map, ~] = show_me_the_spikes( file_path, file_name, draw);       
    spike_times = cellfun(@transpose, spike_times, 'un', 0);      
    nChans = numel( spike_times);        

    % Draw
    figureST( ['PSTH: ' file_name]);
    sp = dealSubplots(4, nChans/4);

    for chan = 1 : nChans                                                            

        taso = bsxfun(@minus, spike_times{chan}, stim_times);
        nhist = histc( transpose(taso), psth_bins);
        nhist = nhist ./ bin_width;

        chan_idx = chan_map.MCS_Chan == chan;
        axes( sp( chan_map.Subplot_idx( chan_idx)))

        plotSE_patch( psth_bins, nhist', 'x', gca, 'k');

        xlabel('Time (s)')
        ylabel('Firing Rate (Hz)')        

        warp_chan = chan_map.Warp_Chan( chan_idx);
        title(sprintf('E%02d', warp_chan))
    end
    
catch err
    err
    keyboard
end
    