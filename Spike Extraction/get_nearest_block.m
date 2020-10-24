function get_nearest_block(file_path)
%
% INPUTS:
%   - file_path
%
% Stephen Town: May 9th, 2020
% - 14 June 2020 - added ability to get blocks for video files

% Default path
if nargin == 0    
    file_path = 'C:\Users\steph\Documents\Multi Channel Systems\Multi Channel Experimenter';
end

% Select file to investigate 
current_dir = pwd;
cd(file_path)
[file_name, ~] = uigetfile( {'*.msrd; *.avi'}); 
cd(current_dir)

if file_name == 0
    return
end

% Base action on extension
[~, file_name, ext] = fileparts(file_name);

switch ext
    case '.msrd'        
        ds = strrep( file_name(1:19), 'T', ' ');            
        max_delta = 15; % seconds
    case '.avi'
        ds = strrep( file_name, '_Track_', ' ');            
        max_delta = inf; % seconds
end


% Strip date time from file name
dt = datetime( ds, 'InputFormat', 'yyyy-MM-dd HH-mm-ss');

fprintf('Searching: %s...\n', file_name);
fprintf('\tFile Date: %s\n', datestr(dt, 'ddd, dd-mmm-yyyy HH:MM:ss'));

% Load block table
dirs.tanks = 'E:\UCL_Behaving';
block_table = build_block_table(dirs.tanks);

% Get minimum time delta 
block_table.delta = seconds(block_table.datetime - dt);
min_t = min( abs( block_table.delta));

if min_t > max_delta    % Return if not within limit
    fprintf('Min time difference = %.0f s: exiting\n', min_t)
    return
else    
    block = block_table( abs( block_table.delta) == min_t, :);  % Confirm datetime of found file
    block = table2struct( block);
    
    fprintf('\tFile Date: %s found\n', datestr( block.datetime, 'ddd, dd-mmm-yyyy HH:MM:ss'));
    fprintf('%s %s...\n', block.Ferret, block.Block)        
end

% Check for h5 files in extracted folder
% (The implicit assumption would be that h5 files have not been extracted,
% but will check anyway)
dirs.h5 = 'E:\MCS_DataManager_h5';
h5_to_put = report_h5_files( dirs.h5, file_name(1:19));

dirs.block = fullfile( dirs.tanks, block.Ferret, block.Block);
h5_in_block = report_h5_files( dirs.block, file_name(1:19));

% If no h5 files - recommend extraction (not sure how to do this via
% command line yet)
if numel(h5_to_put) == 0 && numel(h5_in_block) == 0
    fprintf('Recommend extracting data from %s\n', file_name)
else
    
    % List contents of block and ask about moving all files with same name
    % (across extention types) to this directory
    dirs.block = fullfile( dirs.tanks, block.Ferret, block.Block);
    eval(sprintf('! dir %s', dirs.block))

    moveQ = input('Do you want to move files to this block (y/n)?', 's');
    
    if strcmp(moveQ, 'y')
        
        files_to_move = dir( fullfile( file_path, [file_name '*']));
                
        for i = 1 : numel( files_to_move)    
            src_path = fullfile( file_path, files_to_move(i).name);
            tar_path = fullfile( dirs.block, files_to_move(i).name);
            
            fprintf('\nMoving %s', files_to_move(i).name)
            fprintf('\t(%d)', movefile( src_path, tar_path));
        end     
        
        fprintf('\n')
    end
end



function h5_files = report_h5_files( path_name, file_str)

h5_files = dir( fullfile( path_name, [file_str '*.h5']));

if numel(h5_files) == 0 
    fprintf('No h5 files found in %s\n', path_name)
else
    fprintf('H5 files found:\n')
    
    for i = 1 : numel( h5_files)        
        fprintf('\t%s\n', h5_files(i).name)
    end
end
