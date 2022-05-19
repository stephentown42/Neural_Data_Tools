function varargout = show_me_the_spikes( h5_path, config, trials)
%
% Get spikes with their waveform shapes from filtered electrode data 
% after cleaning.
%
% Note that because multichannel systems is so bad at building things, we
% can't get the same rate from the summary file so, if you care about timiing, maybe
% check that the assumed values here give reasonable results and adjust
% accordingly
%
% Version History:
% ----------------
%   2019-03-19: Created by Stephen Town
%   2019-12-19: Updated 
%   2022-02-23: Copied from spatial coordinates to frontiers project
%   2022-04-29: Added debug stage to look for/remove large amplitude
%   artefacts
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

    % Load electrode data     
    H5 = McsHDF5.McsData( h5_path);        
    fprintf('Loading %s\n', h5_path); 
            
    if isfield(config,'debug')      % Debug option
        
        % Detect large amplitude noise on raw data
        fS = trials.sample_rate(1);
        ind = remove_large_amplitude_noise(H5, config, fS, h5_path);
        
        % Skip if indices are empty (if bad events don't exceed threshold)
        if isempty(ind), return; end
                
        % Load filtered data and remove problematic indices
        fltData = sigproc_utils.load_neural_data(H5, 'Filter Data');
        for chan = 1 : size(fltData, 1)
            fltData(chan, ind{chan}) = nan;        
        end
    else
        fltData = sigproc_utils.load_neural_data(H5, 'Filter Data');
    end
    
    % Alert if no data returned
    if isempty(fltData)
        warning('No neural data for %s %s %s, trial %d',...
            trials.ferret(1), trials.block(1), trials.h5_file(1))
        return 
    end

    % Clean data
    fltData = sigproc_utils.detect_power_loss(fltData);
    
    switch config.cleaning 
        
        case 'by_trial'            
            fltData = clean_data_by_trials(fltData, trials, config);
        
        case 'peristimulus'        
            trigger_times = config.stimTimes - start_time;
            fltData = clean_peristimulus_data(fltData, trigger_times);

        case 'roving'
            fltData = clean_data_in_roving_window(fltData);
    end
    
    % Get diagnostics on signal quality
    summary_stats = get_summary_stats( fltData');
    
    % Create save directory and write diagnostics
    file_dir = fullfile( config.save_dir, erase(trials.h5_file(1),'.h5'));
    if ~isfolder(file_dir), mkdir(file_dir); end
    
    save_name = trials.h5_file(1).replace('.h5','_vStats.csv');
    writetable( summary_stats, fullfile( file_dir, save_name))
    
    % Optional: Select threshold values from alternate file
    % (for when a block is known to give very high thresholds)
    if strcmp(config.threshold.method, 'transplant')
        config.threshold.limits = bsxfun(@times,...
            config.threshold.values, config.threshold.limits');            
    end
        
    % Preassign
    h = waitbar(0, 'Spike extraction');
    nChans = size(fltData, 1);    
            
    % For each channel
    for chan = 1 : nChans
                            
        waitbar(chan/nChans, h)
        
        config.threshold.currentChan = chan;   % Allow channel specific threshold values
        
        % Main extraction process
        [spike_samps, wv] = getSpikeTimes( fltData(chan,:), config.threshold);
        
        % Write spike events as times to nearest microsecond
        spike_times = spike_samps ./ trials.sample_rate(1);  
        fid = fopen(fullfile(file_dir, sprintf('spike_times_C%02d.dat', chan)),'w');
        fprintf( fid, '%.6f\n', spike_times);
        fclose(fid);
        
        % Write waveform data 
        writematrix(round(wv), fullfile(file_dir, sprintf('wv_C%02d.dat', chan)));        
    end      
    
    close(h)    
    
           
catch err
    err
    keyboard
end




function ind = remove_large_amplitude_noise(H5, config, fS, h5_path)


% Use raw data to clean signal
fprintf('\tLoading raw data for signal check...\n')
raw_data = sigproc_utils.load_neural_data(H5, 'Raw Data');

% Examine spectrum of signal                
fprintf('\tChecking psd... ');
[pxx, f, pxxc] = sigproc_utils.get_pwelch(mean(raw_data, 1), fS);

fig = sigproc_utils.plot_psd(f, pxx, pxxc);              
n_ev = sigproc_utils.add_peaks_n_troughs(f, pxx);

fprintf('%d events detected\n', n_ev);
title(sprintf('Signal duration: %.1f s', size(raw_data, 2) / fS),...
    'fontweight','normal','horizontalalignment','right')

% Save figure as png
[~, h5_name, ~] = fileparts(h5_path);        
myPrint( fullfile(config.save_dir, h5_name), 'png', 150)
close(fig)

% Identify indices to drop if there are many peaks (bad data)
n_chan = size(raw_data, 1);
ind = cell(n_chan, 1);

if n_ev > config.psd_event_threshold
    for chan = 1 : n_chan
        ind{chan} = sigproc_utils.find_large_amp_periods(raw_data(chan,:), fS, 3, 2);  
    end
else
    ind = [];
end


function [t, wv] = getSpikeTimes(x, opt)

% This is taken from getMClustEvents_AlignedInterpolated with the threshold
% parameters adjusted for the different electrodes.
%
% Args
%   - x: filtered voltage trace from which to extract spikes
%   - opt: threshold options
%
% Returns:
%   - t: vector of spike times
%   - wv: matrix showing spike waveforms

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


