function compare_recordings( file_paths)
%
% INPUTS
%   - file_paths: cell array of paths to h5 files containing neural data
%   from the same array recorded (usually recorded on different sessions)

% SETTINGS
fRec = 2e4;             % Hz
trial_window = [-1 3];  % Seconds
clean_window = 3;       % Seconds
nChans = 32;            % Assumed

% User input if no args in, just request two files for head-to-head
if nargin == 0    
    file_paths{1} = select_h5_file;
    file_paths{2} = select_h5_file;
end

% Define histogram bins for voltage signals
nBins = 201;    
max_y = 1e8;    % Limits defined from values obtained during sedated recordings
min_y = -max_y;

edges = linspace(min_y, max_y, nBins);
centres = edges(1:end-1) + diff(edges(1:2))/2;

% Preassign
nFiles = numel( file_paths);
[sd_all, sd_trial, sd_clean] = deal( nan( nChans, nFiles));
vProb_all = nan( nBins, nChans, nFiles);


% For each file
for i = 1 : nFiles

    % Load data
    H5 = McsHDF5.McsData( file_paths{i} );

    data = load_h5_analog_stream( H5, 'Filter Data1');
    
    % Get signal stats of interest    
    sd_all(:,i) = nanstd(data, [], 2);   
    vProb_all(:,:,i) = get_voltage_histograms(data, edges);
                        
    % Select only signals around stimulus
    stim = get_MCS_digital_events_obj(H5, 'Digital Events3');       
    
    [trial_data, trigTime] = rm_intertrial_data( stim, data, fRec, trial_window);
   
    sd_trial(:,i) = nanstd(trial_data, [], 2);   
    %vProb_trial(:,:,i) = get_voltage_histograms(trial_data, edges);    
            
    % Clear data around events (for behaving data [i.e. low trial numbers] only)
    if numel( trigTime) < 200
        
        clean_data = clean_peristimulus_data(data, trigTime, clean_window, fRec);
                        
        sd_clean(:,i) = nanstd(clean_data, [], 2);
        %vProb_clean(:,:,i) = get_voltage_histograms(clean_data, edges);
    end
end


% Plot threshold values for spike detection
figure
hold on
h = plot( sd_all);
plot( sd_trial, 'LineStyle','--');
plot( sd_clean, 'LineStyle',':');
xlabel('Channel')
ylabel('Threshold')
legend( repmat(file_paths, 1, 3))

% figure
% area([sd_trial(:,1), sd_trial(:,1), sd_clean(:,1),...
%       sd_trial(:,2), sd_trial(:,2), sd_clean(:,2)],...
%       'LineStyle','none')
%   
% xlabel('Channel')
% ylabel('Threshold')
% legend( [repmat(file_paths{1}, 3, 1); repmat(file_paths{2}, 3, 1)])


keyboard

% Plot voltage distributions for each channel
scaleFactor = 4;

figure('position',[5 558 1920 420])
axes('nextplot','add',...
    'position', [0.03 0.11 0.93 0.82],...
    'TickDir', 'out',...
    'xlim',[0 33] ./ scaleFactor,...
    'xtick',(1:32) ./ scaleFactor,...
    'xticklabel',num2str( transpose(1:32)))
 
set(plotXLine(0),'color',[1 1 1]./2);   % Zero line

for i = 1 : nChans
    for j = 1 : nFiles

        x = i/ scaleFactor + vProb_all(1:end-1, i, j);        
        plot( x, centres, 'color', get(h(j),'color'))
    end
end

xlabel('Channel')
ylabel('pV')


function file_path = select_h5_file
% Helper fcn: Returns full path of user selected file

[filename, pathname] = uigetfile('*.h5');
file_path = fullfile( pathname, filename);


function n_samps = get_voltage_histograms(data, edges)
% Get histogram of voltage signals

% % Define bin edges based on min and max across channels
% min_y = median(min(data, [], 2));
% max_y = median(max(data, [], 2));

% Get number of samples in each bin
n_samps = histc( transpose(data), edges);
n_samps = n_samps ./ size( data, 2);        % Convert to proportion


function data = load_h5_analog_stream( H5, str)

% Find index for filtered neural data
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
    warning('Could not find %s', str)
    data = [];
end


function [trial_data, ev_times] = rm_intertrial_data( stim, data, fRec, trial_window)
%
%   - stim: structure (object) containing link to digital events
%           representing stimuli (sounds)
%   - data: nChan x nSamp array of recorded data
%   - fRec: sample rate of recrodings (Hz)
%   - trial_window: 2-element vector containing offset and duration of
%                   trial window (seconds)

% Define array of samples within trial window
trial_window_offset = round( trial_window(1) * fRec);
trial_window_duration = round( trial_window(2) * fRec);
trial_window = trial_window_offset + (1:trial_window_duration);

% Replicate window around every stimulus event
ev_times = double( stim.Events{1}(1,:)) ./ 1e6; 
ev_samps = round( fRec .* ev_times');
ev_window = bsxfun( @plus, ev_samps, trial_window);

ev_window = ev_window(:);                   % Make vector as easy to work with
ev_window( ev_window > size(data, 2)) = []; % Remove stim at end of session
ev_window = unique(ev_window);              % Remove replicates (e.g. FRA where interstim interval is short)

trial_data = data(:, ev_window); % Don't need to keep intervals between trials
    
    