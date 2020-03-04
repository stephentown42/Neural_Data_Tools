function show_me_the_StimPSTH
%
%
% Created on 30 December 2019 by Stephen Town
%
%
% Enable library
% addpath('C:\Users\Dumbo\Documents\MATLAB\Optional Toolboxes\McsMatlabDataTools')

try
   
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Define folders and drawing options

    dirs = struct();
    dirs.neural_data = 'E:\UCL_Behaving';
    dirs.stim_metadata = 'E:\Behavior\F1703_Grainger\';
    
    if nargin == 0
                
%         cd(dirs.stim_metadata)
%         [stim_file, dirs.stim_metadata] = uigetfile('*level5*');

        % Debug file for setting up script
        stim_file = '18_12_2019 level53_Grainger 15_17_44.462 Block_J7-8.txt';
    end
    
    draw = struct('waveform', true,...
                  'times',  false,...
                  'psth',   true,...
                  'fra',    true);
                            
    bin_width = 0.01;
    psth_bins = -0.1 : bin_width : 0.4;
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Load data    

    [dirs.neural_data, neural_files] = find_neural_file( dirs, stim_file);       
       
    stim = readtable( fullfile( dirs.stim_metadata, stim_file), 'delimiter', '\t');
    
    for i = 1 : numel( neural_files)            
        
        neural_file = neural_files(i).name;
        [spike_times, chan_map, ~] = show_me_the_spikes( dirs.neural_data, neural_file, draw);       
        spike_times = cellfun(@transpose, spike_times, 'un', 0);      
        nChans = numel( spike_times);   

        %%%% NOTE: Here we haven't corrected for the timing differences between
        %%%% TDT and MCS systems. Temporal precision to this level is not
        %%%% immeditately obviously required but inspect data and consider
        %%%% adding correction at some point
    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Draw
        if draw.psth

            figureST( ['PSTH: ' neural_file]);
            sp = dealSubplots(4, nChans/4);

            for chan = 1 : nChans                                                            

                taso = bsxfun(@minus, spike_times{chan}, stim.StartTime);
                nhist = histc( transpose(taso), psth_bins);
                nhist = nhist ./ bin_width;

                chan_idx = chan_map.MCS_Chan == chan;
                axes( sp( chan_map.Subplot_idx( chan_idx)))

                plotSE_patch( psth_bins, nhist', 'x', gca, 'k');

                xlabel('Time (s)')
                ylabel('Firing Rate (Hz)')        

                warp_chan = chan_map.Warp_Chan( chan_idx);
                title(sprintf('E%02d', warp_chan))
            end
        end
    end    
catch err
    err
    keyboard
end


function [tar_path, tar_files] = find_neural_file( dirs, src_file)
            
    % Get block from source file name (if a block was recorded)
    if ~contains(src_file, 'Block_J')
        [tar_path, tar_files] = deal([]);
        warning('Behavioral file does not have corresponding block')
        return
    else
        b_idx = strfind( src_file, 'Block_J');
        block = src_file(b_idx : end-4);
    end
    
    % Get ferret from path
    f_idx = strfind( dirs.stim_metadata, filesep);
    
    if f_idx(end) == numel(dirs.stim_metadata)
        f_idx(end) = [];        
    end
    
    ferret = dirs.stim_metadata( f_idx(end)+1 : end);
   
    % Put information together and check before identifying h5 files
    tar_path = fullfile( dirs.neural_data, ferret, block);
    
    if ~isfolder( tar_path)
        warning('%s does not exist')
        tar_files = [];
    else
        tar_files = dir( fullfile( tar_path, '*.h5'));
                
        if numel(tar_files) == 0
            warning('Could not find any h5 files in %s')
        end
    end
    
    