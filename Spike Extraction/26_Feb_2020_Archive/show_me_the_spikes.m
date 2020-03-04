function varargout = show_me_the_spikes( pathname, filename, options)
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
% Enable library
% addpath('C:\Users\Dumbo\Documents\MATLAB\Optional Toolboxes\McsMatlabDataTools')

try

    % Request file by user
    if nargin == 0
        [filename, pathname] = uigetfile('*.h5');
    end
    
    if nargin < 3
        options = struct('tlim', [0 inf],...
                         'cleaning', 'roving');
        options.draw = struct('waveform', true,...
                               'times', true);
                           
    end
   
    % ASSUMPTIONS
    fS = 2e4;
    
    chan_map_dir = 'C:\Users\steph\Documents';
    chan_map_file = 'Warp_to_WirelessHeadstage_ChanMap.txt';
    chan_map_path = fullfile( chan_map_dir, chan_map_file);    
    chan_map = readtable( chan_map_path, 'delimiter','\t'); 
    
    % Load data 
    H5 = McsHDF5.McsData( fullfile( pathname, filename) );
    
    % Find index for filtered neural data
    h5_idx = 0;
    h5_ok  = false;
    
    while ~h5_ok && h5_idx < numel(H5.Recording{1}.AnalogStream)
        h5_idx    = h5_idx + 1;
        testLabel = H5.Recording{1}.AnalogStream{h5_idx}.Label;
        h5_ok     = contains(testLabel,'Filter Data1');
    end
    
    % Load the data
    fltData = H5.Recording{1}.AnalogStream{h5_idx}.ChannelData;
    [nChans, nSamps] = size(fltData);           

    % Remove the first 3 seconds of recording and crop to max time of 
    % behavioural testing (speeds up code and avoids starting artefacts)             
    offset_time = max([3 options.tlim(1)]);
    offset_samps = round(offset_time * fS);       
    end_samps = min([ceil(options.tlim(2) * fS) nSamps]);   
    fltData = fltData(:, offset_samps: end_samps);
    
    % Clean data
    fltData = detect_disconnections( fltData);
    
    if strcmp(options.cleaning,'peristimulus')
        trigger_times = options.stimTimes - offset_time;
        fltData = clean_peristimulus_data(fltData, trigger_times);
    else
        fltData = clean_data_in_roving_window(fltData);
    end
    
    % Preassign
    [spike_times, wv] = deal( cell( nChans, 1));
    nSpikes = zeros(nChans, 1);
    h = waitbar(0, 'Spike extraction');
    
    % For each channel
    for chan = 1 : nChans
                            
        waitbar(chan/nChans, h)
        
        [spike_samps, wv{chan}] = getSpikeTimes(fltData(chan,:));
        
        spike_times{chan} = offset_time + (spike_samps ./ fS);
  
        nSpikes(chan) = numel(spike_samps);
    end      
    
    close(h)

    % Create figures   
    if options.draw.waveform
        
        figureST( ['Shape: ' filename]);
        sp = dealSubplots(4, nChans/4);     
        
        xlabel(sp(end,1),'Time (ms)')
        ylabel(sp(end,1),'micro V')
                
        spike_time_vec = [-15 : 16] ./ (fS / 1e3);
        
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
    end
    
           
catch err
    err
    keyboard
end



function [t, wv] = getSpikeTimes(x)

% This is taken from getMClustEvents_AlignedInterpolated with the threshold
% parameters adjusted for the different electrodes.
%
% x = filtered voltage trace from which to extract spikes
% b = regression coefficients describing offset and sampling rate
% difference between devices

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
lb = -3.5 * nanstd(x);
ub = -8 * nanstd(x);

% Replace nans with zeros to avoid spline errors
x(isnan(x)) = 0;    

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
if iscolumn(crossThreshold),
    crossThreshold = crossThreshold';
end

% Get interim waveforms
wvIdx  = bsxfun(@plus, crossThreshold', window);
wv     = x(wvIdx);

% Move to next trial if no waveforms are valid
if isempty(wv); return; end

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
if iscolumn(alignedCrossings),
    alignedCrossings = alignedCrossings';
end

% Get waveforms
wvIdx = bsxfun(@plus, alignedCrossings', window); % But sample aligned waveforms
wv    = x(wvIdx);
               
% Calculate time in TDT from wireless MCS samples
t = crossThreshold(:);


