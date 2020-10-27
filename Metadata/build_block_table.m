function T = build_block_table(path_name)
%
% Returns table of blocks on this PC with datetime extracted from tracking
% file name. 
%
% Aim to expand data extracted with additional options in the future
%
% Stephen Town 22nd March 2019
% Updated: 04 Feb 2020

try

% Default tank (will only be right on original computer)
if nargin == 0
    dirs.tanks = 'E:\UCL_Behaving';
else
    dirs.tanks = path_name;
end

% Check for existing block table (To save time)
existing_table = fullfile( dirs.tanks, 'Block_Table.csv');

if exist( existing_table, 'file')
    
    E = readtable( existing_table);
    method = 'append';
else
    method = 'create';
end

% Preassign
[block_date, block_duration, tank_name, block_name] = deal([]);
k = 0;

fig = figure('visible','off');
TT = actxcontrol('TTank.X');
TT.ConnectServer('Local','Me');

% List ferrets
[nFerrets, ferrets] = nDir( dirs.tanks, 'F*');

% For each ferret
for i = 1 : nFerrets
    
    % List blocks in tank
    dirs.tank = fullfile( ferrets(i).folder, ferrets(i).name);
    
    if TT.OpenTank( dirs.tank, 'R')        
        [nBlocks, blocks] = nDir( dirs.tank, 'Block*');
    else
        nBlocks = 0;
    end
        
    % For each block
    for j = 1 : nBlocks
        
        % Check for existing data (fast)
        if strcmp(method,'append')
            if any( strcmp(E.Ferret, ferrets(i).name) & strcmp(E.Block, blocks(j).name))
                continue; 
            end
        end
        
        % Get data from file (slow)
        if TT.SelectBlock(blocks(j).name)
            
            % Get start time for block
            start_time = TT.CurBlockStartTime;
            stop_time = TT.CurBlockStopTime;
            form_start = TT.FancyTime(start_time ,'D-O-Y H:M:S');
            
            % Assign to lists            
            k = k + 1;
            tank_name{k} = ferrets(i).name;
            block_name{k} = blocks(j).name;
            block_date(k) = datenum(form_start, 0);
            block_duration(k) = stop_time - start_time;
        end
    end
end

% Tidy up
TT.CloseTank;
TT.ReleaseServer;
close(fig)

% Convert acquired data to table format
T = table(tank_name(:), block_name(:), block_date(:), block_duration(:),...
        'VariableNames', {'Ferret','Block','DateNum','Duration'});
    
if ~isempty(T)        
    T.datetime = datetime( T.DateNum, 'ConvertFrom', 'datenum');
end

% Add to existing table if required
if strcmp(method,'append')    
    if isempty(T)
        T = E;
    else
        T = [E; T];
    end
    
    if ~issame( size(E), size(T))
        writetable(T, existing_table, 'delimiter', ',')
    end
elseif strcmp(method,'create')
    writetable(T, existing_table, 'delimiter', ',')
end

catch err
    err
    keyboard
end
