function populate_Electrode_Moving_Worksheet()
% function populate_Electrode_Moving_Worksheet()
%
% Populates a template spreadsheet with target locations for next electrode
% movements
%
% Args:
%   None: The user will be presented with a series of dialog boxes to set the relevant parameters and file paths
%
% Returns:
%   New .xlsx file with current and target electrode positions. File name contains array and current date (e.g. Electrode moving F1901_Left_2021_Mar_24.xlsx)
%
% Disclaimer:
% -----------
% The user is encouraged to double check at least some of the generated
% values for security; no responsibility is accepted for incorrect
% movements resulting from outputs generated.
%
% Version History
% ---------------
%   2016: Created by Stephen Town (ST)
%   2018-Apr-22: Updated with new zero and comments (ST)
%   2021-Nov-11: Updated to support broader use by others
% 

% Steps requiring user interaction
[current_zero, chans] = get_settings();

[EM, em_sheet] = get_electrode_moving_info();

tarPath = create_worksheet_from_template(em_sheet);

% Write metadata
myDate = datestr(now,'yyyy_mmm_dd');
xlswrite( tarPath, {em_sheet}, 'Sheet1','A1')                 % Ferret name
xlswrite( tarPath, {strrep(myDate,'_',' / ')}, 'Sheet1','H1') % Current Date
xlswrite( tarPath, {current_zero}, 'Sheet1','B4')    % Zero position


% Convert strings to nan
if iscell(EM.Position(1))
    idx = cellfun(@isstr, EM.Position);
    EM.Position(idx) = {nan};
    EM.Position = cell2mat(EM.Position);
end

% Convert into datenumber (easier to manage)
myDateNum = nan(size(EM, 1), 1);

for i = 1 : size(EM,1)    
    myDateNum(i,1) = datenum(EM.Year(i), EM.Month(i), EM.Day(i));    
end

% Assign back to table
EM.DateNum = myDateNum;


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
        currentPosition{i} = current_zero + C.Depth(end);
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

% Write to worksheet
xlswrite( tarPath, currentPosition, 'C4:C35')
xlswrite( tarPath, Notes,           'E4:E35')
xlswrite( tarPath, LastMoveDate,    'F4:F35')
xlswrite( tarPath, currentDepth,    'G4:G35')

end



function [zeroPos, chans] = get_settings()
% function [zeroPos, chans] = get_settings()
%
% Request confirmation of user settings for the array

    % Create dialog box
    prompt = {'Current zero (mm):','Number of channels in array:'};
    dlgtitle = 'Settings';
    dims = [1 35];
    definput = {'24.9','31'};
    answer = inputdlg(prompt,dlgtitle,dims,definput);

    % Format variables for later use
    zeroPos = str2double(answer{1});    % Electrode zero position
    chans = 0 : str2double(answer{2});   % Channels
end


function [EM, selected_array] = get_electrode_moving_info()
%function EM = get_electrode_moving_info()
%
% Load electrode moving

    % Request file from user
    [file_name, file_path] = uigetfile('*.xlsx','Please select electrode moving spreadsheet');
    
    ssds = spreadsheetDatastore( fullfile( file_path, file_name));
    arrays = sheetnames(ssds, 1);
    
    % Request sheet from user
    fig = uifigure('Position',[100 100 500 600],...
        'Name','Select array you want and close this figure');
    
    uilistbox(fig,...
        'Position',[125 20 200 550],...
        'Items',arrays,... 
        'ValueChangedFcn', @updateEditField); 

    A = struct();
    
    % ValueChangedFcn callback
    function updateEditField(src, ~)
        A.selected_array = src.Value;
    end

    uiwait(fig)
    fprintf('Selected: %s\n', A.selected_array)
    selected_array = A.selected_array;

    % Load data
    EM = readtable( fullfile( file_path, file_name), 'Sheet', A.selected_array);
    EM = EM(~isnan(EM.Channel),:);
end


function tar_path = create_worksheet_from_template(selected_array)
%function tarPath =  create_worksheet_from_template()
% 
% Create a new worksheet based on a template design so that we can populate
% it with metadata, current and future electrode positions. Created file is
% saved in same director
    
    % Get location of template
    [src_file, src_path] = uigetfile('*.xlsx','Please select template to populate');

    % Suggest a name that might be more helpful for this array
    suggested_name = strrep(src_file, 'template_worksheet', datestr(now,'yyyy_mmm_dd'));
    suggested_name = strrep(suggested_name, '.xlsx', ['_' selected_array '.xlsx']);
    
    % Get user to specify save location
    [tar_file, tar_path] = uiputfile('*.xlsx','Save new worksheet as', suggested_name);
                    
    % Copy file to chosen location
    src_path = fullfile( src_path, src_file);
    tar_path = fullfile( tar_path, tar_file);    
    copyfile(src_path, tar_path);
end


