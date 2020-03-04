function copy_behavior_to_tanks

% Define parent directories
dirs.tanks = 'E:\UCL_Behaving';
dirs.behavior = 'E:\Behavior';

% List ferrets
ferrets = dir( fullfile( dirs.tanks, 'F*'));

% For each ferret
for i = 1 : numel(ferrets)
    
    % Extend paths
    dirs.f_tank = fullfile( dirs.tanks, ferrets(i).name);
    dirs.f_behav = fullfile( dirs.behavior, ferrets(i).name);
    
    % List blocks 
    blocks = dir( fullfile( dirs.f_tank, 'Block*'));
        
    % For each block
    for j = 1 : numel(blocks)
        
        % Look for file in behaviour
        search_str = ['*' blocks(j).name '.txt'];
        files = dir( fullfile( dirs.f_behav, search_str));
        
        if numel(files) == 1
            
            target_path = fullfile( dirs.f_tank, blocks(j).name, files.name);
            
            if ~exist( target_path, 'file')                
                fprintf('Copying: %s\n', files.name);                
                [isOK, msg, ~] = copyfile( fullfile( dirs.f_behav, files.name),target_path);
                
                if ~isOK
                   disp(msg)
                end
            end            
                    
        elseif numel(files) > 1
            fprintf('Multiple files found for %s\n', search_str)
        else
            fprintf('No files found for %s\n', search_str)
        end
    end
end
