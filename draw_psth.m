function draw_psth
%
% Draws a bar plot form of the peri-stimulus time histogram showing mean
% firing rate around the time of stimulus presentation
%
% Stephen Town - 24th July 2019

[spike_time_file, spike_time_path] = uigetfile('*.mat','SELECT CHANNEL');
load( fullfile( spike_time_path, spike_time_file), 't')
fprintf('Loaded: %d Spikes\n', numel(t))

[metadata_file, metadata_path] = uigetfile('*.txt','SELECT METADATA');
B = importdata( fullfile( metadata_path, metadata_file));
fprintf('Loaded: %d Stimuli\n', size(B.data, 1))

startTimes = B.data(:, strcmp(B.colheaders,'StartTime')); 
taso = bsxfun(@minus, t, startTimes);   % Time after sound onset

bin_width = 0.01;
bin_edges = -0.2: bin_width : 0.4;   % histogram bin edges in seconds

nHist = histc( transpose( taso), bin_edges);    % Spike counts per bin
nHist = nHist ./ bin_width; % Spike count to spike rate conversion
av_rate = mean( nHist, 2);  % Average across trials

figure;
hold on
bar( bin_edges, av_rate, 'histc');
xlabel('Time (s)')
ylabel('Firing Rate (Hz)')
title( strrep(spike_time_file,'_',' '))