function draw_vStats_vs_Block

% Settings
ferret = 'F1905_Sponge';
hemisphere = 'R';

% Load block table for cross referencing block dates
B = readtable('E:\UCL_Behaving\Block_Table.csv', 'delimiter',',');
B = B( strcmp(B.Ferret, ferret), :);

% Select hemiphere
switch hemisphere
    case 'L'
        file_stub = '*RecB*.mat';
    case 'R'
        file_stub = '*RecA*.mat';
end

% Behaving tests
file_path = fullfile( 'C:\Analysis\Behavioral Recording', ferret);

T_b = get_vStats_across_blocks( B, file_path, file_stub);
T_b.Size = repmat(30, size(T_b, 1), 1);


% FRA tests
file_path = fullfile( 'C:\Analysis\FrequencyTuning', ferret);

T_f = get_vStats_across_blocks( B, file_path, file_stub);
T_f.Size = repmat(60, size(T_f, 1), 1);

% Concatenate
% T = [T_f; T_b];


% Set up figure and colormap
figure('name', ferret)
hold on

chans = unique(T_b.Chan);
nChans = numel(chans);
colors = nan( nChans, 3);
rng(1);

for i = 1 : numel(chans)
    colors(i,:) = hsv2rgb([rand(1) 0.5 0.9]);
end
    
% For each channel
plot_vStats( T_b, chans, colors, 'o')
plot_vStats( T_f, chans, colors, 'd')

xlabel('Date')
ylabel('Std. Dev. (uV)')
    




function plot_vStats( T, chans, colors, m)

for i = 1 : numel(chans) 

    C = T( T.Chan == chans(i), :);
    
    scatter( C.BlockDatetime, C.StdDev, C.Size, colors(i,:), 'filled',...
        'DisplayName', num2str(chans(i)),'marker', m)    
end


function T = get_vStats_across_blocks( B, file_path, file_stub)

try
    
% List blocks
blocks = dir( fullfile( file_path, 'Block*'));
T = [];

% For each block
for i = 1 : numel(blocks)
    
    % Get spike times result file
    block_dir = fullfile( file_path, blocks(i).name);
    spike_times = dir( fullfile( block_dir, file_stub));
    
    % Only one results file should be found, enter debug if not
    if numel(spike_times) ~= 1
        continue
    end
    
    % Load data
    S = load( fullfile( block_dir, spike_times.name), 'vStats');
    
    if ~isfield(S,'vStats')
        continue
    end
    
    % Get block date
    block_table_idx = strcmp(B.Block, blocks(i).name);  
    block_duration = B.Duration( block_table_idx);
    block_datetime = B.datetime( block_table_idx);
    
    if ~any(block_table_idx)
        continue
    end
    
    % Append block to table
    n = size(S.vStats, 1);
    S.vStats.BlockDuration = repmat( block_duration, n, 1);
    S.vStats.BlockDatetime = repmat( block_datetime, n, 1);
    
    % Concatenate table
    T = [T; S.vStats];
end

T = sortrows(T, 'BlockDatetime');

catch err
    err
    keyboard
end