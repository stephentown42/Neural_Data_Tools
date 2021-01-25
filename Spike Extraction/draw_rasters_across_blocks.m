function draw_rasters_across_blocks( tank_dir, ferret, hemisphere, chan, depth)
% function draw_rasters_across_blocks( tank_dir, ferret, hemisphere, chan, depth)
%
% Draws raster plots of spiking activity recorded for a given unit (i.e on 
% activity on a specific channel in a selected hemisphere for all blocks at 
% a specific depth)
%
% Inputs:
%   - tank_dir: Directory containing blocks with extracted spike times
%   - ferret: Subject (e.g. 'F1810_Ursula')
%   - hemisphere: String (e.g. 'Left' or 'Right')
%   - chan: Zero based warp electrode number
%   - depth: Electrode position (more neagive as electrodes advance)
%
% Returns:
%   - Raster plots sorted by speaker angle in world, speaker
%   angle relative to platform, platform angle, behavioral accuracy and
%   response
%   - Line plots showing average firing rate as a function of speaker angle in 
%   world, speaker angle relative to platform, platform angle, behavioral 
%   accuracy and response
%   - Bar Plots showing standard deviation vs. date for each block
%   - Scatter plot of standard deviation vs. peak firing rate for each
%   block
%
% Stephen Town - Oct 2020

try

% Settings
raster_bins = -0.25 : 0.001 : 0.75;             
speaker_angles = [150 : -30 : -150, 180];

% Default demo arguments
switch nargin 
    case 0       % Demo args
        tank_dir = 'C:\Analysis\Behavioral Recording';        
        ferret = 'F1810_Ursula';        
        hemisphere = 'Right';   
        chan = 6;       
        depth = -2.6;     
end                        
        
% Extend paths
dirs.tank = fullfile( tank_dir, ferret); 
dirs.behav = fullfile( 'E:\Behavior', ferret);
dirs.electrode_pos = 'C:\Analysis\Electrode Positions\CSV\';

switch hemisphere
    case 'Left'
        file_stub = '*RecB*.mat';
    case 'Right'
        file_stub = '*RecA*.mat';
end
 
% Add path containing helper functions
addpath( genpath( 'C:\Users\steph\Documents\MATLAB\Spike Extraction'))

% Load electrode position data
position_file = sprintf('Electrode moving - %s_%s.csv', ferret(1:5), hemisphere);
E = get_depth_vs_date( dirs.electrode_pos, position_file, false, chan);

E.Depth = round(E.Depth, 3);                        % Avoid precision error                    
if ~isnan(depth), E = E(E.Depth == depth, :); end   % Filter for depth
                    
% Load block table
B = readtable('E:\UCL_Behaving\Block_Table.csv', 'delimiter',',');
B = B( strcmp(B.Ferret, ferret), :);

% For each recording site (channel x depth)
for i = 1 : size(E, 1)
        
    % Filter for dates at specific location
    b_idx = B.datetime >= E.start_dt(i) & B.datetime < E.end_dt(i);
    blocks = B( b_idx, :);
    n_blocks = size(blocks, 1);
    
    [rMat, chan_std, behav] = deal( cell(n_blocks, 1));
     nTrials = nan( n_blocks, 1); 
    rPeak = nan(2, n_blocks); 
                    
    % For each file
    for j = 1 : n_blocks

        % Load spike times    
        S = load_file( dirs.tank, blocks.Block{j}, file_stub);        
        
        if isempty(S), continue; end    % Skip if no date (e.g. block was an FRA)
        
        % Load behavioral file
        B = load_behavioral_file( dirs.behav, blocks.Block{j});
                
        if isempty(B)
            continue
        else
            behav{j} = B;
        end
        
        % Correct mismatched times
        S.matched_times( isnan(S.matched_times)) = [];        
        if size(B, 1) ~= numel(S.matched_times)
           continue 
        end
                
        % Map warp channel to MCS channel
        mcs_channel = S.chan_map.MCS_Chan( S.chan_map.Warp_Chan == E.Channel(i));
        S.spike_times = S.spike_times{mcs_channel }; 
        
        % Get raster (or PSTH later)
        taso = bsxfun(@minus, transpose(S.spike_times), S.matched_times);
        nhist = histc( taso, raster_bins);
        rMat{j} = transpose(nhist);             
        
        % Get sound evoked response
        rPeak(:,j) = mean(histc( taso, [0 0.3]), 2);
        
        % Note threshold
        nTrials(j) = size(nhist, 2);   % yes... columns, it's right (i think)
        std_dev = S.vStats.StdDev( S.vStats.Chan == mcs_channel);
        chan_std{j} = repmat( std_dev, nTrials(j), 1);
    end
    
    % Remove missing blocks
    missing_idx = isnan(nTrials);    
    rMat(missing_idx) = [];
    rPeak(:,missing_idx) = [];
    chan_std(missing_idx) = [];
    behav(missing_idx) = [];
    blocks(missing_idx,:) = [];
    nTrials(missing_idx) = [];
    n_blocks = size(blocks, 1);
                      
    
    % Unpack behavioral variables
    vars = {'Correct','Response','Speaker_Location','CenterSpoutRotation'};
    
    for j = 1 : numel(vars)
        eval( sprintf('%s = [];', vars{j}))
        
        for k = 1 : numel(behav)
           eval( sprintf('%s = [%s; behav{k}.%s];', vars{j}, vars{j}, vars{j}))
       end
    end
    
    World_Speaker_Angle = speaker_angles( Speaker_Location);
    World_Speaker_Angle = World_Speaker_Angle(:);
    HeadSpeakerLocation = World_Speaker_Angle - CenterSpoutRotation;
    
    idx = HeadSpeakerLocation <= -180;
    HeadSpeakerLocation(idx) = HeadSpeakerLocation(idx) + 360; 
               
    idx = HeadSpeakerLocation > 180;
    HeadSpeakerLocation(idx) = HeadSpeakerLocation(idx) - 360;
    
    % Show raster across blocks
    figure
    hold on
    drawRaster( cell2mat(rMat), raster_bins, gca, cell2mat(chan_std), cmocean('thermal'))
    
    figure
    sp = dealSubplots(1,5);
           
    cb(1) = drawSortedRaster( cell2mat(rMat), raster_bins, sp(1), World_Speaker_Angle, cmocean('phase'), true);
    xlabel(cb(1), 'Speaker Angle: World (°)')        
    set(cb(1),'xtick',[-120 0 120])
    
    cb(2) = drawSortedRaster( cell2mat(rMat), raster_bins, sp(2), HeadSpeakerLocation, cmocean('phase'), true);
    xlabel(cb(2), 'Speaker Angle: Head (°)')
    set(cb(2),'xtick',[-120 0 120])
    
    cb(3) = drawSortedRaster( cell2mat(rMat), raster_bins, sp(3), CenterSpoutRotation, cmocean('phase'), true);
    xlabel(cb(3), 'Platform Angle (°)')
    set(cb(3),'xtick',[-120 0 120])
    set(sp(1:3),'clim',[-180 180])
    
    cb(4) = drawSortedRaster( cell2mat(rMat), raster_bins, sp(4), Correct, redblue, true);
    xlabel(cb(4), 'Correct')
    set(cb(4),'xtick',[0 1])
    
    cb(5) = drawSortedRaster( cell2mat(rMat), raster_bins, sp(5), Response, flipud(redblue), true);
    xlabel(cb(5), 'Response')
    set(cb(5),'xtick',[3 9],'xticklabel',{'R','L'})
    
    xlabels(sp, 'Time (s)')   
    set(sp,'FontSize', 14,'xtick',-0.25:0.25:0.75, 'xlim',[-0.25, 0.75])
    set(sp(2:5),'yticklabel','')
    ylabels(sp(2:5),'')
    
    % Plot firing rate vs. feature    
    count_window = [0 0.25];
    spike_count = cell2mat(rMat);
    start_bin = find( round(raster_bins, 3) == count_window(1));
    end_bin = find( round(raster_bins, 3) == count_window(2));
    spike_count = spike_count(:, start_bin : end_bin);
    spike_rate = sum(spike_count, 2) ./ diff(count_window);    
    
    figure
    rp = dealSubplots(1,5);
    
    plot_rate(World_Speaker_Angle, spike_rate, rp(1), 'Speaker Angle: World (°)')
    plot_rate(HeadSpeakerLocation, spike_rate, rp(2), 'Speaker Angle: Head (°)')
    plot_rate(CenterSpoutRotation, spike_rate, rp(3), 'Platform Angle (°)')
    plot_rate(Correct, spike_rate, rp(4), 'Correct')
    plot_rate(Response, spike_rate, rp(5), 'Response')
    
    set(rp, 'ylim', [0 max(spike_rate)])
    
    % Plot joint rate
    figure
    colormap(plasma)
    jp = dealSubplots(1,1);    
    plot_joint_rate(HeadSpeakerLocation, World_Speaker_Angle, spike_rate,...
                    jp, 'Sound Angle: Head (°)', 'Sound Angle: World (°)');
    
               
    % Show standard deviation vs date
    chan_std = cellfun(@(v) v(1), chan_std);
    
    figure;
    hold on    
    bar(blocks.datetime, chan_std, 'FaceColor','k','Barwidth',0.9)
    ylabel('Std Deviation')
    title( sprintf('%s - %s %02d', ferret(1:5), hemisphere, E.Channel(i)))
           
    % Plot correlation between peak firing rate and threshold
    figure
    scatter( chan_std, rPeak(1,:),'filled')
    xlabel('Std Deviation')
    ylabel('Response Amplitude (spike count)')   
    title( sprintf('%s - %s %02d', ferret(1:5), hemisphere, E.Channel(i)))
end 
catch err
    err
    keyboard
end



function S = load_file( tank_dir, block, file_stub)

S = [];
files = dir( fullfile( tank_dir, block, file_stub));

if numel(files) > 1
    warning('multiple files detected')
end

if isempty( files)
    warning('No file (%s) detected', file_stub)
else
    S = load( fullfile( tank_dir, block, files.name));
end


function B = load_behavioral_file( file_path, block)

B = [];
file_stub = ['*', block '.txt'];
file = dir( fullfile( file_path, file_stub));

if numel(file) == 0
    warning('No behavioral file found')
elseif numel(file) > 1
    warning('Multiple files found')
else
    B = readtable( fullfile( file_path, file.name), 'delimiter', '\t');
end


function plot_rate(x, spike_rate, ax, x_str)
%
% INPUTS:
%   - x: 1-by-n vector of values used for ordering trials (e.g. sound angle)
%   - spike rate: 1-by-n vector of spike rates on individual trials in some
%   time window determined earlier
%   -ax: axis to plot data
%   - x_str: parameter name
%
% Returns
%   graphics objects to selected figure showing either a bar plot (<6
%   parameter values) or line + error bars (>5 parameter values)

% Get unique parameter values
ux = unique(x);
nX = numel(ux);
[mx, sx] = deal( nan(nX, 1));

% For each parameter
for i = 1 : nX

   rate_i = spike_rate(x == ux(i));

   % Bar plots if there are a small number of parameter values (indicative
   % of categorical data - e.g. correct/error)
   if nX < 6
       barSE(ux(i), mean(rate_i), std(rate_i), ax, 'k');
   
   % Line with standard error if looking at many parameter values (e.g.
   % continuous data)
   else
       mx(i) = mean(rate_i);
       sx(i) = std(rate_i) ./ sqrt(numel(rate_i)-1);
   end
end

if nX >= 6
    plotSE_patch(ux, mx, sx, ax, 'k');
end

% Axis formatting
xlabel(ax, x_str)
ylabel(ax, 'Firing Rate (Hz)')


function [imH, cbar] = plot_joint_rate(x, y, spike_rate, ax, x_str, y_str)
    
    [nX, uniqueX, ~] = nUnique(x);
    [nY, uniqueY, ~] = nUnique(y);
    z = nan(nY, nX);
    
    xy = [x, y];
    uniqueXY = unique(xy, 'rows');
    nXY = size(uniqueXY, 1);
    
    for i = 1 : nXY
        
        rows = ismember(xy, uniqueXY(i,:), 'rows');           
        x_idx = uniqueX == uniqueXY(i,1);
        y_idx = uniqueY == uniqueXY(i,2);        
        z(y_idx, x_idx) = mean( spike_rate(rows));
    end
        
    imH = imagesc(uniqueX, uniqueY, z, 'parent', ax);
    cbar = colorbar;
    
    set(ax, 'xtick', [-1:1] * 180, 'ytick', [-1:1] * 180)
    xlabel(x_str)
    ylabel(y_str)