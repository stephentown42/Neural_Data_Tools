function varargout = show_me_the_spikes( h5_path, options)
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
% can't get the same rate from the summary file so, if you care about timiing, maybe
% check that the assumed values here give reasonable results and adjust
% accordingly
%
% Created on 13 March 2019 by Stephen Town
% Updated on 13 Dec 2019
%
% INPUT:
%   - h5_path: path to h5 file
%   - options: struct with following fields...
%               - time limit over when to load spikes from
%               - cleaning: whether (and how) to clean
%               = sample rate of headstage (usually 20kHz)
%
% Enable library
% addpath('C:\Users\Dumbo\Documents\MATLAB\Optional Toolboxes\McsMatlabDataTools')

try

    % Request file by user
    if nargin == 0
        [filename, pathname] = uigetfile('*.h5');
        h5_path = fullfile( pathname, filename);
    else
        [~, filename] = fileparts( h5_path);
    end
    
    % Default options
    if ~isfield( options, 'fS'), options.fS = 2e4; end
    if ~isfield( options, 'tlim'), options.tlim = [0 inf]; end
    if ~isfield( options, 'cleaning'), options.cleaning = 'none'; end    
    if ~isfield( options, 'draw')        
       options.draw = struct('waveform', true,'times', true);
    end    
    if ~isfield( options, 'threshold')                          
       options.threshold = struct('metric', 'std',...       % or 'voltage'
                                  'method', 'universal',... % or 'byChan'
                                  'limits', [-3 -8]);     % or n x 2 array of channel specific values
    end
           
    % Get channel mapping
    chan_map_dir = 'C:\Users\steph\Documents';
    chan_map_file = 'Warp_to_WirelessHeadstage_ChanMap.txt';
    chan_map_path = fullfile( chan_map_dir, chan_map_file);    
    chan_map = readtable( chan_map_path, 'delimiter','\t'); 
    
    % Load data 
    H5 = McsHDF5.McsData( h5_path);
        
    fltData = load_neural_data(H5, 'Filter Data1');    
    [nChans, nSamps] = size(fltData);           

    % Apply any hard time limits
    if ~isinf(options.tlim(2))        
        end_samp = round(options.tlim(2) * options.fS);
        end_samp = min([end_samp, nSamps]);     % Ensure it fits signal
        fltData = fltData(:, 1:end_samp);        
    end    
    
    % Remove the first 3 seconds of recording and crop to max time of 
    % behavioural testing (speeds up code and avoids starting artefacts)             
%     start_time = max([3 options.tlim(1)]);
%     start_samps = round(start_time * options.fS);       
%     end_samps = min([ceil(options.tlim(2) * options.fS) nSamps]);   
%     fltData = fltData(:, start_samps: end_samps);
    
    start_time = 0;

    % Clean data
    fltData = detect_disconnections( fltData);
    
    if strcmp(options.cleaning,'peristimulus')        
        
        trigger_times = options.stimTimes - start_time;
        fltData = clean_peristimulus_data(fltData, trigger_times);
        
    elseif strcmp(options.cleaning,'roving')
        fltData = clean_data_in_roving_window(fltData);
    end
    
    % Get diagnostics on signal quality
    summary_stats = get_summary_stats( fltData');
    
    % Optional: Select threshold values from alternate file
    % (for when a block is known to give very high thresholds)
    if strcmp(options.threshold.method, 'transplant')
        options.threshold = import_threshold( options.threshold);
    end
    
    % Preassign
    [spike_times, wv] = deal( cell( nChans, 1));
    nSpikes = zeros(nChans, 1);
    
    h = waitbar(0, 'Spike extraction');
    
    % For each channel
    for chan = 1 : nChans
                            
        waitbar(chan/nChans, h)
        
        options.threshold.currentChan = chan;   % Allow channel specific threshold values
        
        [spike_samps, wv{chan}] = getSpikeTimes( fltData(chan,:), options.threshold);
        
        spike_times{chan} = start_time + (spike_samps ./ options.fS);
  
        nSpikes(chan) = numel(spike_samps);
    end      
    
    close(h)

    % Create figures   
    if options.draw.waveform
        
        figureST( ['Shape: ' filename]);
        sp = dealSubplots(4, nChans/4);     
        
        xlabel(sp(end,1),'Time (ms)')
        ylabel(sp(end,1),'micro V')
                
        spike_time_vec = [-15 : 16] ./ (options.fS / 1e3);
        
        for chan = 1 : nChans
                        
            warp_chan = chan_map.Warp_Chan( chan_map.MCS_Chan == chan);
            ax_idx = chan_map.Subplot_idx( chan_map.MCS_Chan == chan);
            
            plotSE_patch( spike_time_vec, wv{chan}, 'x', sp(ax_idx), 'k');       
            
            title(sp(ax_idx), sprintf('E%02d: n = %d', warp_chan, nSpikes(chan)))
        end
                
        set(sp,'xcolor','none','ycolor','none')
        linkaxes(sp,'y')
    end

    if options.draw.times
        
        figureST(['Time: ' filename]);
        hold on  

        for chan = 1 : nChans
            
            warp_chan = chan_map.Warp_Chan( chan_map.MCS_Chan == chan);
            
            spike_chan = repmat( warp_chan, nSpikes(chan), 1);

            scatter( spike_times{chan}, spike_chan,'o','filled')               
        end
        
        ylim([0 31])
        xlabel('Time (s)')
        ylabel('Channel')
    end
    
    % Return output
    if nargout > 0
        varargout{1} = spike_times;
        varargout{2} = chan_map;
        varargout{3} = wv;
        varargout{4} = summary_stats;
        varargout{5} = options;
    end
    
           
catch err
    err
    keyboard
end


function data = load_neural_data(H5, str)
%    
% Find index for filtered neural data within H5 file structure and load
 
h5_idx = 0;
h5_ok  = false;

while ~h5_ok && h5_idx < numel(H5.Recording{1}.AnalogStream)
    h5_idx    = h5_idx + 1;
    testLabel = H5.Recording{1}.AnalogStream{h5_idx}.Label;
    h5_ok     = contains(testLabel, str);
end

if h5_ok
    data = H5.Recording{1}.AnalogStream{h5_idx}.ChannelData;
else
    data = [];
    warning('Could not find requested stream')
end



function S = import_threshold(S)
%
% INPUT:
%   - S: struct with fields...
%       - limits: 1x2 array containing multiples of standard deviations 
%           used for upper and lower bounds
%
% Returns:
%   - S: struct with fields...
%       - limits: mx2 array containing threshold values for each channel 
%                  based on standard deviation previously obtained in a 
%                  different block

[filename, pathname] = uigetfile('*.mat');
load( fullfile( pathname, filename), 'vStats')

S.limits = bsxfun(@times, vStats.StdDev, S.limits);


function [t, wv] = getSpikeTimes(x, opt)

% This is taken from getMClustEvents_AlignedInterpolated with the threshold
% parameters adjusted for the different electrodes.
%
% INPUTS
%   - x: filtered voltage trace from which to extract spikes
%   - opt: threshold options

% Parameters
wInt = 1;
interpFactor = 4;

interpInt  = wInt / interpFactor;    % Method dependent (i.e. if you interpolate or not)
window     = -15 : wInt : 16;
interpWind = -15 : interpInt  : 16;

nW = numel(window)+1;               % These are regardless of method (interpolated or not)
alignmentZero = find(window == 0);

% Preassign
[t, wv] = deal([]);

% Format
if iscolumn(x), x = transpose(x); end

% Get upper (ub) and lower (lb) bounds
if strcmp( opt.metric, 'std')           % Using standard deviation of signal
    if strcmp( opt.method, 'universal')
        lb = opt.limits(1) * nanstd(x);
        ub = opt.limits(2) * nanstd(x);    
    
    elseif strcmp( opt.method, 'transplant')                
        lb = opt.limits( opt.currentChan, 1);        
        ub = opt.limits( opt.currentChan, 2);
    
    elseif strcmp( opt.method, 'byChan')        
        limits = opt.limits( opt.currentChan, :);        
        lb = limits(1) * nanstd(x);
        ub = limits(2) * nanstd(x);
    end
    
elseif strcmp( opt.metric, 'voltage')   % Using specific values
    if strcmp( opt.method, 'universal')
        lb = opt.limits(1);
        ub = opt.limits(2);
    
    elseif strcmp( opt.method, 'byChan')        
        limits = opt.limits( opt.currentChan, :);        
        lb = limits(1);
        ub = limits(2);
    end    
end

% Identify thrshold crossings
lcIdx = find(x < lb);
ucIdx = find(x < ub);

% Remove events exceeding the upper threshold                    
lcIdx = setdiff(lcIdx,ucIdx);                                   %#ok<*FNDSB>

% Move to next trial if no events were found
if isempty(lcIdx); return; end

% Identify crossing points in samples
crossThreshold = lcIdx([0 diff(lcIdx)]~=1);

% Remove events where window cannot fit
crossThreshold(crossThreshold < nW) = [];
crossThreshold(crossThreshold > (length(x)-nW)) = [];

% Make row vector
if iscolumn(crossThreshold)
    crossThreshold = crossThreshold';
end

% Get interim waveforms
wvIdx  = bsxfun(@plus, crossThreshold', window);
wv     = x(wvIdx);

% Move to next trial if no waveforms are valid
if isempty(wv); return; end

% Remove any waveforms that contain nans
rm_idx = sum( isnan(wv), 2) > 0;
crossThreshold( rm_idx) = [];
wv( rm_idx, :) = [];

% Interpolate waveforms
wv = spline(window, wv, interpWind);

% Align events
[~, peakIdx] = min(wv,[],2); 
peakIdx = round(peakIdx / interpFactor);     % Return interpolated peakIdx to original sample rate
alignmentShift = peakIdx' - alignmentZero;
alignedCrossings = crossThreshold + alignmentShift;

% Reset events where window cannot fit (i.e. don't
% throw away, just include without alignment)
alignedCrossings(alignedCrossings < nW) = crossThreshold(alignedCrossings < nW);                     
alignedCrossings(alignedCrossings > (length(x)-nW)) = crossThreshold(alignedCrossings > (length(x)-nW));

% Make row vector
if iscolumn(alignedCrossings)
    alignedCrossings = alignedCrossings';
end

% Get waveforms
wvIdx = bsxfun(@plus, alignedCrossings', window); % But sample aligned waveforms
wv    = x(wvIdx);
               
% Report back just the samples for now
t = crossThreshold(:);


