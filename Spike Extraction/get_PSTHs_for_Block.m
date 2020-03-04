function get_PSTHs_for_Block(tank, block, options)
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
           
    if nargin == 0
       file_path = uigetdir('E:\UCL_Behaving'); 
           
       options.save = true;
       options.draw = struct('waveform', true,...
                       'times',  true,...
                       'psth',   true,...
                       'fra',    true,...
                       'ev_align', false);           
    else
        file_path = fullfile( tank, block);
    end
              
    % Get file names
    [h5_files, behav_file] = get_files( file_path);
    
    % Load behavioural data    
    matched_times = align_event_times(file_path, options.draw.ev_align);          
    
    if isempty(matched_times), return; end

    % Define options for processing
    options.fS = 2e4;
    options.tlim = minmax(matched_times) + [-5 5];
    options.cleaning = 'peristimulus';   
    options.stimTimes = matched_times;
    
    % For each neural recording array
    for i = 1 : numel(h5_files)
       
        fprintf('Processing: %s\n', h5_files(i).name)
        
         if options.save           
            save_name = strrep(h5_files(i).name, '.h5','_spikes.mat');
            save_path = fullfile( file_path, save_name);            
            
            if exist( save_path, 'file')
                fprintf('%s exists - skipping\n', save_name)
                continue
            end
        end      
        
        % Get spike times               
        [spike_times, chan_map, wv] = show_me_the_spikes( file_path, h5_files(i).name, options);       
        spike_times = cellfun(@transpose, spike_times, 'un', 0);      
                          
        if options.draw.psth
            draw_psth( h5_files(i).name, spike_times, matched_times, chan_map)
        end         
        
        if options.save           
            save( save_path, 'spike_times','wv','options')                        
        end        
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
    
    
    
