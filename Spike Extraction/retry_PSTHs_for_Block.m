function retry_PSTHs_for_Block(tank, block, opt)
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
%   - opt: struct with fields for...
%
% OUTPUT (optional)
%   - figure showing PSTHs for each channel
%   - .mat file containing spike times and waveforms for later sorting or
%   visualization
%
% Dependencies:
%   - align_event_times.m 
%   - draw_psth.m 
%   - show_me_the_spikes.m
% 
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
    opt.fS = 2e4;                               % Define options for processing
    opt.clean_window = 3;
    opt.cleaning = 'peristimulus';       
    opt.threshold = struct('metric', 'std',...       % or 'voltage'
                                  'method', 'transplant',... % or 'byChan'
                                  'limits', [-3, -8]);     % or n x 2 array of channel specific values                 
    
    if nargin < 3               % Defaults unless user says otherwise                 
        opt.save = true;
        opt.overwrite = true;
        opt.save_root = 'C:\Analysis\Behavioral Recording';
        opt.draw = struct('waveform', true,...      % Graphs to draw
                               'times',  true,...
                               'psth',   true,...
                               'raster', true,...
                               'ev_align', false);           
    end
                         
    aet_opt = struct('draw',  opt.draw.ev_align,... % event alignment
                         'max_accept_delta', 1);
    
    raster_bins = -0.2 : 0.001 : 0.75;
             
    
    % MAIN
    % Get file names    
    h5_files = dir( fullfile( file_path, '*.h5'));
    
    % Check if output files already exist (and return if all files have
    % already been analysed
    if opt.save 
        
        output_path = get_output_path( tank, block);              
        
        if ~opt.overwrite
            h5_files = filter_for_processed(output_path, h5_files);   

            if isempty(h5_files)
                fprintf('%s already processed', block);
                return
            end                        
        end    
    end
    
    % Load behavioural data    
    [matched_times, trial_idx] = align_event_times(file_path, aet_opt);              
    if isempty(matched_times), return; end
    
    opt.stimTimes = matched_times;
    opt.tlim = minmax(matched_times) + [-5 5];  % Time limit for cleaning (for accelerating code)
    
    % For each neural recording array
    for i = 1 : numel(h5_files)
       
        fprintf('Processing: %s\n', h5_files(i).name)
        
        % Get spike times               
        h5_path = fullfile( file_path, h5_files(i).name);
        [spike_times, chan_map, wv, vStats] = show_me_the_spikes( h5_path, opt);       
        spike_times = cellfun(@transpose, spike_times, 'un', 0);      
                       
        wv = struct('mean', cellfun(@mean, wv, 'un', 0),...
                    'std', cellfun(@std, wv, 'un', 0));

        % Create outputs
        if opt.save   
            
            % Define save path and create if non-existent
            [~, ferret] = fileparts( tank);
            save_path = fullfile( opt.save_root, ferret, block);            
            if ~isfolder(save_path), mkdir(save_path); end
            
            % Save spike times and extraction options
            spike_file = strrep( h5_files(i).name, '.h5', '_spiketimes.mat');
            save( fullfile( save_path, spike_file), 'spike_times','wv',...
                'matched_times','trial_idx','chan_map', 'opt','vStats')
            
            % Save signal statistics underlyng extraction
            % stats_file = strrep( spike_file, 'spiketimes.mat','vStats.csv');
            % writetable( vStats, fullfile( save_path, stats_file), 'delimiter', ',')            
        end        
        
        % Skip if nowt to plot
        if all( cellfun(@isempty, spike_times)), continue; end
        
        if opt.draw.psth    % Draw PSTH
            fig.PSTH = draw_psth( h5_files(i).name, spike_times, matched_times, chan_map);
            
            if opt.save
                
                psth_file = strrep( h5_files(i).name, '.h5', '_PSTH.png');            
                save_figure( fig.PSTH, save_path, psth_file, 150)            
            end
        end         
                
        if opt.draw.raster  % Draw Raster                        
                        
            fig.raster = figure( 'name', ['Raster: ' h5_files(i).name],...
                                 'position', [50 50 1850 950]);
            sp = dealSubplots(4, numel(spike_times)/4);       
            
            for chan = 1 : numel(spike_times)                                                            

                taso = bsxfun(@minus, transpose(spike_times{chan}), matched_times);
                nhist = histc( taso, raster_bins);

                chan_idx = chan_map.MCS_Chan == chan;
                ax = sp( chan_map.Subplot_idx( chan_idx));

                drawRaster( nhist', raster_bins, ax)

                warp_chan = chan_map.Warp_Chan( chan_idx);
                title(sprintf('E%02d: C%02d', warp_chan, chan))
            end    
            
            if opt.save
                rast_file = strrep( h5_files(i).name, '.h5', '_Raster.png');
                save_figure( fig.raster, save_path, rast_file, 150)
            end
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
    
    save_name = strrep(h5_files(i).name, '.h5','_spikeTimes.mat');
    save_path = fullfile( file_path, save_name);
    to_remove(i) = exist( save_path, 'file') > 0;
end

% Remove files
h5_files(to_remove) = [];


 function save_figure(f, save_path, file_name, res)

figure(f)
myPrint( fullfile( save_path, file_name), 'png', res)
close(f)  