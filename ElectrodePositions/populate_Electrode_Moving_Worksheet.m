function populate_Electrode_Moving_Worksheet

% 22 April 2018: Updated with new zero and comments (ST)

% Options
ferret  = 'F1701';  % F1808_Skittles | F1703 Grainger | F1701_Pendleton | F1810_Ursula
array   = 'Left';   % Left | Right
zeroPos = 25;    % Electrode zero position
chans   = 0 : 31;   % Channels

% Calculate static variables from options
myDate   = datestr(now,'yyyy_mmm_dd');
em_sheet = sprintf('%s_%s', ferret(1:5), array);

% Define paths
rootDir = Cloudstation('CoordinateFrames\Ephys\Electrode Moving');

metaFile = 'Electrode moving.xlsx';
refFile  = 'Electrode moving notesheet_32 Chan_autoTest.xlsx';

% Copy target file as new version
tarFile = strrep(refFile, 'autoTest', myDate);
tarFile = strrep(tarFile, 'notesheet_32 Chan', em_sheet);
tarPath = fullfile( rootDir, tarFile);
srcPath = fullfile( rootDir, refFile);

copyfile(srcPath, tarPath);

% Write metadata
xlswrite( tarPath, {em_sheet}, 'Sheet1','A1')     % Ferret name
xlswrite( tarPath, {strrep(myDate,'_',' / ')}, 'Sheet1','H1') % Current Date
xlswrite( tarPath, {zeroPos}, 'Sheet1','B4')    % Zero position

% Load electrode moving
EM = xls2struct(rootDir, metaFile, em_sheet);
EM = struct2table(EM);
EM = EM(~isnan(EM.Channel),:);

% Preassign
nRows = size(EM,1);
Position = nan(nRows, 1);

% Convert strings to nan
if iscell(EM.Position(1))
    idx = cellfun(@isstr, EM.Position);
    EM.Position(idx) = {nan};
    EM.Position = cell2mat(EM.Position);
end

% For each row
for i = 1 : nRows  
    
    % Convert into datenumber (easier to manage)
    myDateNum(i,1) = datenum(EM.Year(i), EM.Month(i), EM.Day(i));
    
    % Convert number format
%     if ~ischar(EM.Position{i})
        Position(i) = EM.Position(i);
%         Position(i) = EM.Position{i};
%     end
end

% Assign back to table
EM.DateNum  = myDateNum;
EM.Position = Position;

clear myDateNum Position

% Calculate depth relative to zero
EM.Depth = EM.Position - EM.Zero;

% Preassign
nChans = numel(chans);
[currentDepth, currentPosition,...
    LastMoveDate, Notes] = deal(cell(nChans,1));

% For each channel
for i = 1 : nChans
    
    % Filter
    C = EM(EM.Channel==chans(i),:);
    
    % Sort by date
%     [~, idx] = sort(C.DateNum);
%     C = C(idx,:);    
    C = sortrows(C,{'DateNum','Depth'},{'ascend','descend'});
    
    % Note current position and date of last movement    
    if ~isempty(C)
        currentPosition{i} = zeroPos + C.Depth(end);
        currentDepth{i}    = C.Depth(end);    
        LastMoveDate{i}    = datestr(C.DateNum(end),'dd mmm');
    end
        
    % Mark electrodes that are blocked    
    if isnan(currentPosition{i})
       Notes{i} = 'X';
    else
       Notes{i} = '';
    end
end

% Write to file
xlswrite( tarPath, currentPosition, 'C4:C35')
xlswrite( tarPath, Notes,           'E4:E35')
xlswrite( tarPath, LastMoveDate,    'F4:F35')
xlswrite( tarPath, currentDepth,    'G4:G35')