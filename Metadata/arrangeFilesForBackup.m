function arrangeFilesForBackup(flag)

try

% Define paths 
dirs.dropbox  = 'C:\Users\steph\Dropbox\Data';
dirs.behavior = 'E:\Behavior';
dirs.webcam   = 'C:\Users\steph\Videos\Realsense';
dirs.TDT      = 'E:\UCL_Behaving';

% Define flag if undefined
if ~exist('flag','var'), flag = 0; end

% Define ferrets of interest
ferrets = dir( fullfile(dirs.TDT, 'F1*'));

% Note today's date
currentTime = now + flag;
str = [datestr(currentTime, 'dd_mm_yyyy') '*'];

% List webcam videos
webcam.str   = [datestr(currentTime, 'yyyy-mm-dd') '*'];
webcam.files = dir( fullfile( dirs.webcam, sprintf('%s.avi', webcam.str)));

% Ignore video files less than 10 MB in size
webcam.file_size = cat(1, webcam.files.bytes);
webcam.files( webcam.file_size < 1e7) = [];

% List webcam dates
for i = 1 : numel(webcam.files)
    
    Y = str2num(webcam.files(i).name(1:4));
    M = str2num(webcam.files(i).name(6:7));
    D = str2num(webcam.files(i).name(9:10));
    H = str2num(webcam.files(i).name(18:19));    
    MN = str2num(webcam.files(i).name(21:22));
    S = str2num(webcam.files(i).name(24:25));
    
   webcam.date(i) = datenum(Y,M,D,H,MN,S);   
end

if exist('webcam_copy','var')
    webcam.copy = webcam_copy == 1;
else
    webcam.copy = false;
end

% For each ferret
for i = 1 : numel(ferrets)
    
    fprintf('%s\n', ferrets(i).name)
    
    % Extend paths
    dirs.ferret.behavior = fullfile( dirs.behavior, ferrets(i).name);
    dirs.ferret.dropbox  = fullfile( dirs.dropbox, ferrets(i).name);
    dirs.ferret.TDT = fullfile( dirs.TDT, ferrets(i).name);
    
    % List behavioral files for today
    files = dir(fullfile( dirs.ferret.behavior, str));
    
    % For each file
    for j = 1 : numel(files)            
        
        % Copy file to dropbox 
        srcFile = fullfile(dirs.ferret.behavior, files(j).name);
        tarFile = fullfile(dirs.ferret.dropbox,  files(j).name);        
        copyfile_myVersion(srcFile, tarFile)  
                
        % Copy file to block 
        block.idx = strfind(files(j).name,'Block');
        block.str = files(j).name(block.idx:end-4);
        
        dirs.block.TDT = fullfile( dirs.ferret.TDT, block.str);         
        if ~isfolder(dirs.block.TDT)
            warning('Could not find %s', dirs.block.TDT); continue
        end
        
        tarFile = fullfile( dirs.block.TDT, files(j).name);
        copyfile_myVersion(srcFile, tarFile)    % Use same source file as backing up to dropbox
                
        % Identify webcam file
        % Get time difference between webcam files and behavioral files
        webcam.delta = abs(webcam.date - getBehavioralFileDate(files(j).name));
        [webcam.discrep, webcam.idx] = min(webcam.delta);
        webcam.target = webcam.files(webcam.idx).name;
        
        % Warn if min difference in file time is large (> 5 mins)
        if webcam.discrep > seconds2days(300)
            warning('Large difference in webcam timing')            
            continue
        end                           
        
        % Move webcam file
        srcFile = fullfile(dirs.webcam,    webcam.target);
        tarFile = fullfile(dirs.block.TDT, webcam.target);    
        movefile_myVersion(srcFile, tarFile)    
                        
        % Move webcam matlab file
        if contains( webcam.target, '_AT1.avi')
            webcam.target = strrep(webcam.target,'_AT1.avi','_AT.txt');            
        else
            webcam.target = strrep(webcam.target,'.avi','.txt');            
        end
        
        srcFile = fullfile(dirs.webcam,    webcam.target);
        tarFile = fullfile(dirs.block.TDT, webcam.target);
        movefile_myVersion(srcFile, tarFile)   
    end
end


catch err
    err
    keyboard
end

function copyfile_myVersion(srcFile, tarFile)
% Copy file if it doesn't already exist
if ~exist(srcFile,'file')
    fprintf('%s does not exist\n', srcFile)
    return
end

if ~exist(tarFile,'file')
    copyfile( srcFile, tarFile,'f')
end


function movefile_myVersion(srcFile, tarFile)

% Copy file if it doesn't already exist
if ~exist(srcFile,'file')
    fprintf('%s does not exist\n', srcFile)
    return
end

if ~exist(tarFile,'file')
    movefile( srcFile, tarFile,'f')
end