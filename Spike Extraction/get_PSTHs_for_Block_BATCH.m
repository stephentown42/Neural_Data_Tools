function get_PSTHs_for_Block_BATCH

% Specify data tanks where ferrets are
dirs.parent = 'E:\UCL_Behaving';
ferrets = {'F1701_Pendleton','F1703_Grainger'};

% Options
options.save = true;
options.draw = struct('waveform', false,...
                       'times',  false,...
                       'psth',   false,...
                       'fra',    false,...
                       'ev_align', false);   

% For each ferret
for i = 1 : numel( ferrets)
        
    % List blocks 
    tank = fullfile( dirs.parent, ferrets{i});
    blocks = dir( fullfile( tank, 'Block*'));
    
    fprintf('%s\n', ferrets{i})
    
    % For each block
    for j = 1 : numel(blocks)
        
        % Prechecks to exclude folders without extracted data
        block_path = fullfile( tank, blocks(j).name);
        h5_files = dir( fullfile( block_path, '*.h5'));
        behav_files = dir( fullfile( block_path, '*Block*.txt'));        
        
        if numel(h5_files) == 0 || numel(behav_files) == 0
            continue
        end
       
        fprintf('\tProcessing: %s\n', blocks(j).name)
        
        % Run main extraction function (this can take a while and is very
        % memory intensive so don't even try parallel processing)
        get_PSTHs_for_Block( tank, blocks(j).name, options)        
    end    
end
