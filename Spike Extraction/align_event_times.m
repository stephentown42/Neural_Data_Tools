function matched_times = align_event_times(file_path, draw)
%
%
% 12 Feb 2020 by Stephen Town
%
% Takes start times from behavioral text file (referenced in TDT time
% frame) and finds nearest event on digital event channel representing
% stimulus onset (play now). Does not correct for DAC-ADC latency 
%
% INPUTS
% - file_path: path to directory containing behavioural file and h5 files
% with stimulus sync signal (DOut/Digital Events3)
% - draw (optional): shows alignment of times for visual inspection
%
% OUTPUTS:
% - matched_times: array of stimulus times where time is defined by the
% multichannel systems clock

try
           
    % Define folders and drawing options   
    if nargin == 0        
       file_path = uigetdir('E:\UCL_Behaving'); 
    end
    
    % Get file names
    [h5_files, behav_file] = get_files( file_path);
    
    % Draw start times in behaviour
    B = readtable( fullfile( file_path, behav_file));
    nTrials = size(B, 1);
    
    if isempty(B)
        matched_times = []; return
    end
    
    % Highlight to user if selecting one of multiple files
    if numel(h5_files) > 1
        fprintf('Heads up: Multiple h5 files detected\n')
        fprintf('Taking events from %s\n', h5_files(1).name)
    end
 
    % Load event times
    H5 = McsHDF5.McsData( fullfile( file_path, h5_files(1).name) );
    stim_obj = get_MCS_digital_events_obj(H5, 'Digital Events3');   
    
    if isempty(stim_obj), matched_times = []; return; end
    
    event_times = double( stim_obj.Events{1}(1,:)); 
    event_times = event_times ./ 1e6;
    
    % Align times     
    time_delta = abs( bsxfun(@minus, B.StartTime , event_times));
    [~, min_idx] = min(time_delta, [], 2);
    matched_times = event_times(min_idx);    
    
    % Optional visualization
    if draw
        figure;
        hold on
        scatter( B.StartTime, zeros( nTrials, 1), 'filled')
        scatter( matched_times, zeros( nTrials, 1)-1, 'filled')
        scatter( event_times, ones(size(event_times)), 'filled')
        set(gca,'ytick', 0 : numel(h5_files),'ylim',[-1 1])
        xlabel('Time (s)')
    end
        
catch err
    err
    keyboard
end
    


function [h5_files, behav_file] = get_files( file_path)
    
    h5_files = dir( fullfile( file_path, '*.h5'));
    behav_file = dir( fullfile( file_path, '*Block*.txt'));

    if numel(behav_file) == 0
       error('No behavioral file detected') 
    end

    if numel(behav_file) > 1
       error('Multiple behavioral files detected') 
    else
        behav_file = behav_file(1).name;
    end

    if numel(h5_files) == 0
       error('No behavioral file detected') 
    end