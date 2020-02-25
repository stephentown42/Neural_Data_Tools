function qualityAssessment_step1_generatePSTHs

% Define paths
dirs.home  = Cloudstation('Vowels\Spatial_Unmasking');
dirs.behav = fullfile(dirs.home,'Behavior');
dirs.MClus = 'C:\Analysis\Portable MClust Events AlignedInterpolated';
dirs.save  = fullfile(dirs.home,'\Ephys\QualityAssessment');

% Define headers
headers = {'Trial','CorrectionTrial','StartTime','CenterReward',...
            'F1','F2','F3','F4','HoldTime','Atten','Pitch','Side',...
            'Response','RespTime','Correct','SpatialMask'};

% Specify start time offset
offset = -0.5; % seconds
        
% List subjects
ferrets = dir( fullfile( dirs.behav, 'F*'));

% For each subject
for i = 1 : numel(ferrets)

    % List behavioral files
    dirs.ferret = fullfile(dirs.behav, ferrets(i).name);
    bFiles = dir( fullfile(dirs.ferret, '*Block*.txt'));
    
    % For each behavioral file
    for j = 1 : numel(bFiles)

        % Get event time directories
        dirs.ev = dir( fullfile(dirs.MClus, strrep(bFiles(j).name,'.txt','*')));
        
        % Alert user if no directories
        if numel(dirs.ev) == 0
            fprintf('Events missing: %s\n', bFiles(j).name); continue
        end        
                                
        % Import behavioral data
        B = importdata( fullfile(dirs.ferret, bFiles(j).name));
        B = array2table(B.data,'VariableNames',headers);      
        
        % Create figure
        f = figure('name',bFiles(j).name);
        
        % For each hemisphere
        for k = 1 : numel(dirs.ev)
            
            % List channel files       
            dirs.chan = fullfile(dirs.MClus, dirs.ev(k).name);
            chanFiles = dir( fullfile(dirs.chan, '*.mat'));
            
            % Double check channel files
            if numel(chanFiles) == 0
                fprintf('No channels: %s\n', dirs.ev(k).name); continue
            end
            
            % Create axes
            sp = subplot(1,2,k);
            set(sp,'nextPlot','add','tag',num2str(k))
            xlabel('Time (s)')
            ylabel('Channel')
            
            % Draw data
            drawData( chanFiles, dirs.chan, sp, B.StartTime+offset)          
        end
        
        % Create save directory
        dirs.ferSave = fullfile(dirs.save, ferrets(i).name);
        
        if ~isdir(dirs.ferSave), mkdir(dirs.ferSave); end
        
        % Save plot
        saveas(f, fullfile(dirs.ferSave, strrep(bFiles(j).name,'txt','fig')))
        close(f)       
    end
end

function drawData(files, pathname, ax, startTime)

nFiles = numel(files);
% h = nan(nFiles,1);
nRate = cell(1,nFiles);

% For each channel
for i = 1 : nFiles
    
    % Load spike times
    spike = load( fullfile(pathname, files(i).name));
    
    % Generate psth
    taso  = bsxfun(@minus, spike.t, startTime);
    nHist = histc( transpose(taso), -0.1 : 0.01 : 0.9);  
    nRate{i} = mean(nHist, 2) ./ 0.01;
        
    % Normalize data
%     nRate = nRate ./ max(nRate);
    
    % Plot data
%     h(i) = plot(-0.095 : 0.01 : 0.895, nRate(1:end-1),...
%                     'parent',ax,'tag',files(i).name);        
end

imagesc(-0.095 : 0.01 : 0.895, 1:16, transpose(cell2mat(nRate)),'parent',ax)
cbar = colorbar('Location','northoutside');
ylabel(cbar,'Firing Rate (Hz)')
axis tight
