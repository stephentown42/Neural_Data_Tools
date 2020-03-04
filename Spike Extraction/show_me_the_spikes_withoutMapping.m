function varargout = show_me_the_spikes( pathname, filename, draw)
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
        draw = struct('waveform',true,'times',true);
    end
   
    % ASSUMPTIONS
    fS = 2e4;
    
    % Load data 
    H5 = McsHDF5.McsData( fullfile( pathname, filename) );       
    [fltData, h5_ok] = get_electrode_data_from_h5(H5, 'Filter Data1');
    
    if ~h5_ok        
        [raw_data, ~] = get_electrode_data_from_h5(H5, 'Electrode Raw Data');   
        fltData = [];
        
        for i = 1 : size(raw_data, 1)
            fprintf('Filtering channel %d\n', i)
            fltData(i,:) = bandpass(raw_data(i,:),[300 5000], fS);
        end       
    end
                
    nChans = size(fltData, 1);           
         
    % Remove the first 3 seconds of recording
    offset_time = 3;
    offset_samps = round(offset_time * fS);       
    fltData = fltData(:, offset_samps:end);
    
    % Preassign
    [spike_times, wv] = deal( cell( nChans, 1));
    nSpikes = zeros(nChans, 1);
    
    % For each channel
    for chan = 1 : nChans
                            
        [spike_samps, wv{chan}] = getSpikeTimes(fltData(chan,:));
        
        spike_times{chan} = offset_time + (spike_samps ./ fS);
  
        nSpikes(chan) = numel(spike_samps);
    end        

    % Create figures   
    if draw.waveform
        
        figureST( ['Shape: ' filename]);
        sp = dealSubplots(4, nChans/4);     
        
        xlabel(sp(end,1),'Time (ms)')
        ylabel(sp(end,1),'micro V')
                
        spike_time_vec = [-15 : 16] ./ (fS / 1e3);
        
        for chan = 1 : nChans                        
            
            if ~isempty(wv{chan})
                plotSE_patch( spike_time_vec, wv{chan}, 'x', sp(chan), 'k');       
            end
            
            title(sp(chan), sprintf('%d: n = %d', chan, nSpikes(chan)))
        end
                
        set(sp,'xcolor','none','ycolor','none')
        linkaxes(sp,'y')
    end

    if draw.times
        
        figureST(['Time: ' filename]);
        hold on  

        for chan = 1 : nChans
            
            spike_chan = repmat( chan, nSpikes(chan), 1);

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

function [fltData, h5_ok] = get_electrode_data_from_h5(H5, str)
    
    h5_idx = 0;
    h5_ok  = false;
    
    while ~h5_ok && h5_idx < numel(H5.Recording{1}.AnalogStream)
        h5_idx    = h5_idx + 1;
        testLabel = H5.Recording{1}.AnalogStream{h5_idx}.Label;
        h5_ok     = contains(testLabel, str);
    end
    
    if h5_ok
        fltData = H5.Recording{1}.AnalogStream{h5_idx}.ChannelData;
    else
        fltData = [];
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
lb = -4 * std(x);
ub = -10 * std(x);

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


