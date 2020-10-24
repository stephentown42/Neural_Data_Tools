function eData = draw_depth_vs_date( file_path, file_name, draw)
%
% INPUT:
%   - file_path: parent directory of electrode moving file
%   - file_name: electrode moving file name (.csv file)
%   - draw (optional): whether to show the figure of electrode positions
%                      vs. time
%
% RETURNS:
%   - eData: Table containing electrode positions (and durations)
%
% Adapted from FRAs_by_date.m
% Stephen Town - 06 June 2020


% Demoe / default args
if nargin == 0
    [file_name, file_path] = uigetfile('*.csv');    
end

if nargin < 3
    draw = true;
end

% Import electrode positions (sites) 
eData = get_electrode_data( file_path, file_name, draw);


function F = get_electrode_data( file_path, file_name, draw)

% Load data     
E = readtable( fullfile( file_path, file_name),'delimiter',',');

% Get depth relative to zero
E.Depth = E.Position - E.Zero;

% Get time at which electrode moved to position 
E.start_dt = datetime( E.Year, E.Month, E.Day);
E.Day = [];
E.Month = [];   % remove unnecessary columns
E.Year = [];

% Get time at which each electrode left that position 
current_time = datetime(clock);
electrodes = unique(E.Channel);
F = [];

for i = 1 : numel( electrodes)
        
    I = E(E.Channel == electrodes(i),:);    % Data for one electrode
    I = sortrows(I, {'start_dt','Depth'},{'ascend','descend'});
    I.end_dt = circshift(I.start_dt, -1);
    I.end_dt(end) = current_time;
    
    F = [F; I]; % Append to new table
end

% Duration for which the electrode was at this position
F.Duration = days(F.end_dt - F.start_dt);

% Plot length of time for each recording
if draw
    
    F = sortrows( F, 'Duration');
    
    figure('name', file_name)
    subplot(122)
    hold on

    for i = 1 : size(F,1)

        plot( [0 F.Duration(i)], [i i],'marker','.','MarkerSize',8,...
            'DisplayName', sprintf('C%02 %.3fmm', F.Channel(i), F.Depth(i)))
    end

    set(gca,'ytick',[1 size(F,1)],'color',[0 0 0] + 0.15)
    xlabel('Days')
    ylabel('Site')
end

% Plot position vs date
F = sortrows(F, {'Channel','Depth','start_dt'},{'ascend','descend','ascend'});

if draw 
    subplot(121)
    hold on

    for i = 1 : numel( electrodes)

        I = F(F.Channel == electrodes(i),:);    % Data for one electrode

        h = plot( I.start_dt, I.Depth, 'Marker','.',...
            'MarkerSize',8, 'DisplayName', num2str(electrodes(i)));
        c = get(h,'color');

        text(I.start_dt(end) + days(7), I.Depth(end), sprintf('%02d', electrodes(i)),...
            'FontWeight','bold','Color', c,'FontSize',8)    
    end

    ylabel('Depth (mm)')    
    set(gca,'color',[0 0 0] + 0.15)
end
