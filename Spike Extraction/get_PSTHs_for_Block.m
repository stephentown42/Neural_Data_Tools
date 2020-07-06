function get_PSTHs_for_Block(tank, block, options)
%
% Designed primarily for quick assessment of event related responses,
% particularly for click responses with short duration.
%
% Processes multiple neural recordings (stored as h5 files exported from
% Multichannel DataManager) that may correspond to different headstages
% used simultaneously (e.g. to rec left/right hemispheres together)
%
% INPUT:
%   - tank: path to TDT tank containing block
%   - block: block name (directory) containing h5 files
%   - options: struct with fields for...
%
% OUTPUT (optional)
%   - figure showing PSTHs for each channel
%   - .mat file containing spike times and waveforms for later sorting or
%   visualization
%
% Dependencies:
%   - correct_event_times.m 
%   - draw_psth.m 
%   - show_me_the_spikes.m
%
% Stephen Town
%   - Branched, 31 Jan 2020
%   - Updated, 05 July 2020

try
          
    % Get block path if not entered
    if nargin == 0 
       file_path = uigetdir('E:\UCL_Behaving', 'SELECT BLOCK PATH'); 
       
       if ~isempty(file_path)
        [tank, block] = fileparts( file_path);                         
       else
           return
       end
    else
        file_path = fullfile( tank, block);
    end
    
    % SETTINGS        
    options.fS = 2e4;                               % Define options for processing
    options.clean_window = 3;
    options.cleaning = 'peristimulus';       
    options.threshold = struct('metric', 'std',...       % or 'voltage'
                                  'method', 'universal',... % or 'byChan'
                                  'limits', [-2.5 -6]);     % or n x 2 array of channel specific values                 
    
    if nargin < 3               % Defaults unless user says otherwise                 
        options.save = false;
        options.draw = struct('waveform', true,...      % Graphs to draw
                               'times',  true,...
                               'psth',   true,...
                               'raster', true,...
                               'ev_align', false);           
    end
                         
    aet_options = struct('draw',  options.draw.ev_align,... % event alignment
                         'max_accept_delta', 1);
    
    raster_bins = -0.2 : 0.001 : 0.5;
             
    
    % MAIN
    % Get file names    
    h5_files = dir( fullfile( file_path, '*.h5'));
    
    % Check if output files already exist (and return if all files have
    % already been analysed
    if options.save
        
        output_path = get_output_path( tank, block);              
        
        h5_files = filter_for_processed(output_path, h5_files);   
        
        if isempty(h5_files), return; end
    end    
    
    % Load behavioural data    
    matched_times = align_event_times(file_path, aet_options);              
    if isempty(matched_times), return; end
    
    options.stimTimes = matched_times;
    options.tlim = minmax(matched_times) + [-5 5];  % Time limit for cleaning (for accelerating code)
    
    % For each neural recording array
    for i = 1 : numel(h5_files)
       
        fprintf('Processing: %s\n', h5_files(i).name)
        
        % Get spike times               
        h5_path = fullfile( file_path, h5_files(i).name);
        [spike_times, chan_map, wv, v_stats] = show_me_the_spikes( h5_path, options);       
        spike_times = cellfun(@transpose, spike_times, 'un', 0);      
                       
        % Draw PSTH
        if options.draw.psth
            draw_psth( h5_files(i).name, spike_times, matched_times, chan_map)
        end         
        
        % Draw Raster
        if options.draw.raster
            
            % Create figure
            fig = figure( 'name', ['Raster: ' h5_files(i).name],...
                        'position', [50 50 1850 950]);
            sp = dealSubplots(4, numel(spike_times)/4);       

            % For each channel
            for chan = 1 : numel(spike_times)                                                            

                taso = bsxfun(@minus, transpose(spike_times{chan}), matched_times);
                nhist = histc( taso, raster_bins);

                chan_idx = chan_map.MCS_Chan == chan;
                ax = sp( chan_map.Subplot_idx( chan_idx));

                drawRaster( nhist', raster_bins, ax)

                warp_chan = chan_map.Warp_Chan( chan_idx);
                title(sprintf('E%02d: C%02d', warp_chan, chan))
            end    

            % Save figure and close
%             fig_file = strrep( h5_files(i).name, '.h5', '_raster');
%             myPrint( fullfile( save_path, fig_file), 'png', 150)
%             close(fig)
        end
        
        
        
        % Save output
        if options.save           
            save( save_path, 'spike_times','wv','options')   
            
            stats_file_out = strrep(h5_files(i).name, '.h5','_signalStats.csv');
            stats_path_out = fullfile( output_path, stats_file_out);
            writetable( v_stats, stats_path_out, 'delimiter', ',');
        end        
    end 
    
catch err
    err
    keyboard
end
    

function output_path = get_output_path( tank, block)

% Specify output path
[~, ferret] = fileparts( tank); 
output_path = fullfile('C:\Analysis\Behavioral Recording', ferret, block);

% Make directory if non-existant
if ~isfolder( output_path)
   mkdir( output_path)       
end     


function h5_files = filter_for_processed(file_path, h5_files)
%
% Removes files from list for which an equivalent results file already
% exists

% Preassign
n_files = numel(h5_files);
to_remove = false(n_files, 1);

% Check existence of each results file
for i = 1 : n_files
    
    save_name = strrep(h5_files(i).name, '.h5','_spikes.mat');
    save_path = fullfile( file_path, save_name);
    to_remove(i) = exist( save_path, 'file') > 0;
end

% Remove files
h5_files(to_remove) = [];

% Notify user if all files already exist
if all( to_remove)
    fprintf('All files in %s already processed\n', block)
end

    