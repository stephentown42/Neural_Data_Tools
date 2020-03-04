function show_me_the_FRA
%
%
% Created on 13 December 2019 by Stephen Town
%
%
% Enable library
% addpath('C:\Users\Dumbo\Documents\MATLAB\Optional Toolboxes\McsMatlabDataTools')

try
   
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Define folders and drawing options

    dirs = struct();
    dirs.neural_data = 'E:\UCL_Behaving';
    dirs.stim_metadata = 'E:\Behavior';
    
    if nargin == 0
        cd(dirs.neural_data)
        [neural_file, dirs.neural_data] = uigetfile('*.h5');
                
        cd(dirs.stim_metadata)
        [stim_file, dirs.stim_metadata] = uigetfile('*FRA*');
    end
    
    draw = struct('waveform', true,...
                  'times',  false,...
                  'psth',   true,...
                  'fra',    true);
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Load data    

    [spike_times, chan_map, ~] = show_me_the_spikes( dirs.neural_data, neural_file);
    spike_times = cellfun(@transpose, spike_times, 'un', 0);      
    nChans = numel( spike_times);
    
    
    stim = readtable( fullfile( dirs.stim_metadata, stim_file), 'delimiter', '\t');
    
    [freqs, levels] = meshgrid( unique(stim.Frequency), unique(stim.dB_SPL));
    
    %%%% NOTE: Here we haven't corrected for the timing differences between
    %%%% TDT and MCS systems. Temporal precision to this level is not
    %%%% immeditately obviously required but inspect data and consider
    %%%% adding correction at some point
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Draw
    
    if draw.psth
    
        figureST( ['PSTH: ' neural_file]);
        sp = dealSubplots(4, nChans/4);
        
        bin_width = 0.01;
        psth_bins = -0.1 : bin_width : 0.2;
        
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
    
    
    if draw.fra
        
        figureST(['FRA: ' neural_file]);        
        sp = dealSubplots(4, nChans/4);  
        
        fra_bin = [0 0.1];
        
        for chan = 1 : nChans
                            
            taso = bsxfun(@minus, spike_times{chan}, stim.StartTime);
            nhist = histc( transpose(taso), fra_bin);
            nhist = nhist(1,:)' ./ diff(fra_bin);    
            
            spike_rate = nan( size( freqs));
            
            for stim_idx = 1 : numel(freqs)
                
                rows = ismember([stim.Frequency stim.dB_SPL],...
                                [freqs(stim_idx) levels(stim_idx)],'rows');
                                
                spike_rate(stim_idx) = mean(nhist(rows));
            end
            
            chan_idx = chan_map.MCS_Chan == chan;
            axes( sp( chan_map.Subplot_idx( chan_idx)))  
            
            imagesc( freqs(1,:) ./ 1e3, levels(:,1), spike_rate) 
        
            xlabel('Frequency (kHz)')
            ylabel('Level (dB SPL)')
                        
            warp_chan = chan_map.Warp_Chan( chan_idx);
            title(sprintf('E%02d', warp_chan))
            
            axis tight
        end
        
        colormap(magma)
    end        

    
catch err
    err
    keyboard
end


