function draw_psth( file_name, spike_times, ev_times, chan_map)
%
% Drawing function used to visualize stimulus responses from spike times
% that have previously been extracted (e.g. using ????)
%
% INPUTS (required):
%   - filename: .mat file containing...
%       - spike_times: cell array, with n elements each containing times of
%       spikes for a specific channel (where n is the number of channels
%       and the index is the channel according to the multichannel systems
%       recording software)
%       - options: structure containing metadata from the spike detection
%       script and event times
%
% INPUTS (optional):
%   - spike_times: Times of spikes (in seconds)
%                  Each channel must be in a separate cell in an m-by-1 cell array
%   - ev_times: Times of triggers (in seconds) in a 1-by-n double array
%   - chan_map: table containing subplot indices for each recording channel
%   with corresponding electrode number (e.g. according to warp
%   nomenclature) and chennel number (e.g. on  multichannel systems)
%
% OUTPUTS:
%   - PSTH figure containing plots for each recording channel based on
%   position on recording array, with electrode (e.g. warp) number in
%   title. Firing rate shown as mean +/ s.e.m across all trials
%
% See also:
%   - get_PSTHs_for_Block.m (generates compatible data files)
%
% Stephen Town: February 2020

    % Drawing Options
    bin_width = 0.01;
    psth_bins = -0.2 : bin_width : 0.8;

    % Parse inputs
    if nargin == 0       
        [file_name, path_name] = uigetfile('E:\UCL_Behaving', '*.mat'); 
    
        load( fullfile( path_name, file_name), 'spike_times', 'options')
        ev_times = options.stimTimes;              
    end

    if nargin < 4                   % Default channel map
        chan_map_dir = 'C:\Users\steph\Documents';
        chan_map_file = 'Warp_to_WirelessHeadstage_ChanMap.txt';
        chan_map_path = fullfile( chan_map_dir, chan_map_file);
        chan_map = readtable( chan_map_path, 'delimiter','\t');
    end
        
    % Create figure
    figure( 'name', ['PSTH: ' file_name],...
        'units','normalized',...
        'outerposition',[0 0 1 1]);

    nChans = numel( spike_times);
    sp = dealSubplots(4, nChans/4);
    
    for chan = 1 : nChans

        taso = bsxfun(@minus, spike_times{chan}, ev_times(:));
        nhist = histc( transpose(taso), psth_bins);
        nhist = nhist ./ bin_width;

        chan_idx = chan_map.MCS_Chan == chan;
        axes( sp( chan_map.Subplot_idx( chan_idx)))

        plotSE_patch( psth_bins, nhist', 'x', gca, 'k');

        xlabel('Time (s)')
        ylabel('Firing Rate (Hz)')
        ylim([0 max(ylim)])
        
        warp_chan = chan_map.Warp_Chan( chan_idx);
        title(sprintf('E%02d', warp_chan))
    end