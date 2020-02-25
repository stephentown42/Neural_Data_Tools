function trialMask_Batch_pitch

% It's very clear that there are trials on which there are no spikes on any
% channel and it's likely these are artifacts rather than biological
% behavior given the coherence across channels. These trials should be
% masked during analysis. It would be useful to report the trial identities

% Define paths
rootDir  = Cloudstation('Vowels\Perceptual_Constancy\Pitch');
behavDir = fullfile(rootDir,'Behavior');
saveDir  = fullfile(rootDir,'Ephys\TrialMasks_Fixed');

% List subjects
ferrets = {'F1201_Florence','F1203_Virginia','F1217_Clio','F1304_Flea'};

% For each subject
for i = 1 : numel(ferrets)
    
    % List files
    ferDir = fullfile( behavDir, ferrets{i});
    files  = dir(fullfile(ferDir,'*.txt'));

    % Create save subdirectory
    ferSave = fullfile(saveDir, ferrets{i});
    
    if ~isdir(ferSave), mkdir(ferSave); end
    
    % For each file
    parfor j = 1 : numel(files)
        
        % Check if already run        
        saveFile = strrep(files(j).name,'.txt','.mat');
        savePath = fullfile( ferSave, saveFile);
        
        if exist(savePath,'file'), continue; end
        
        % Run main function
        trialMask = main(ferDir, files(j).name);         
         
        % Save file        
        parsave( savePath,trialMask);
    end
end

function parsave(savePath, trialMask)

save( savePath,'-struct','trialMask');


function trialMask = main(ferDir, bFile)
%
% Preassign output
trialMask  = struct('label',[],'data',[]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Data Checks
%
% Import behavioral data and get stimulus onset times
B = importdata( fullfile(ferDir, bFile)); 

% Return if no trials
if ~isstruct(B)    
    warning('No trials to process %s', bFile);     
    return
end

% Return "all trials ok" if not enough trials
if size(B.data,1) < 25
    warning('Too few trials to process %s', bFile);     
    trialMask  = struct('data',ones(size(B.data,1),2),'label',bFile);
    return
end

% Find neural data
neuralPath = 'C:\Analysis\MClust Events AlignedInterpolated';
neuralStr  = strrep(bFile,'.txt','*');
neuralDirs = dir( fullfile( neuralPath, neuralStr));

% Return if no neural data
if isempty(neuralDirs)
    warning('Could not find any neural data - check %s exists', neuralStr)
    
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Format options
opt.style  = 'short';   % 'verbose' prints trial details to command window
opt.filter = true;      % true removes problematic trials / false doesn't
opt.draw   = false;

% Define threshold parameters
stdThreshold = 1;
nChanEqZero = 12;

% Define temporal parameters
startT   = -0.25;     % seconds
endT     = 1;         % seconds
binWidth = 0.01;      % seconds
offset   = 0.5;       % Time between start time marker and stimulus onset (s)

% Define channel mapping
chanMap = transpose( [14 13 12 11;
                      15 04 05 10;
                      16 03 06 09;
                      02 01 08 07]);

% Define edges for PSTH
binEdges   = startT : binWidth : endT;
binCenters = binEdges(1:end-1)+(binWidth/2);
startTimes = B.data(:,strcmp(B.colheaders,'StartTime')) - offset;


% Define anon fcn
myFlt = @(x,y) x(y,:);

% Create analysis figures
if opt.draw
    f1 = figure('color','w');
    ax = [subplot(1,3,1) subplot(1,3,2) subplot(1,3,3)]; 
    set(ax,'nextPlot','add');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get trial mask

% For each neural directory (representing one hemisphere)
for i = 1 : numel(neuralDirs)
   
    % List channels available
    i_Path    = fullfile(neuralPath, neuralDirs(i).name);
    chanFiles = dir( fullfile(i_Path, '*.mat'));
    nChans    = numel(chanFiles);     

    % Preassign
    [y, nRate] = deal(cell(nChans,1));
    
    % For each channel
    for j = 1 : nChans
                
        % Load spike times
        spikes = load( fullfile(i_Path, chanFiles(j).name),'t');
        
        % Calculate spike times relative to stimulus onset
        taso = bsxfun(@minus, spikes.t, startTimes);
        
        % Calculate trial PSTH
        nSpikes  = histc(transpose(taso), binEdges);
        nSpikes  = transpose(nSpikes);
        nRate{j} = nSpikes ./ binWidth;
        
        % Check data quality      
        yJ   = sum(nSpikes,2);              % Count spikes across time
        nJ   = max([median(yJ) 1]);           % Avoid division by zero
        y{j} = transpose(yJ) ./ nJ;         % Express relative to median number across trials
    end                  
    
    % Identify trials to mask
    y = cell2mat(y);  
    trialZero = bsxfun(@eq, y, 0);        % y == 0
    rateMask  = sum(trialZero,1) > nChanEqZero;  % Trials where > x channels = 0
    maskIndex = find(rateMask);          % Logical to index       
    
    % Apply filter
    startTimes_flt = startTimes(rateMask==0);      
    nRate_flt = cellfun(myFlt, nRate, repmat({rateMask==0}, size(nRate)),'un',0);
    y_flt = y(:,rateMask == 0);
    
    % Get deviation across channels
    yS = std(y_flt,[],1);
    yS = smooth(yS,3);
    
    % Create and apply std dev mask
    stdMask = yS < stdThreshold;                % Threshold std
    startTimes_Slt = startTimes_flt(stdMask); 
    nRate_Slt = cellfun(myFlt, nRate_flt, repmat({stdMask}, size(nRate_flt)), 'un',0);
        
    % Get trial mask from remaining times
    trialMask.label = [trialMask.label {neuralDirs(i).name}]; 
    trialMask.data  = [trialMask.data  ismember(startTimes, startTimes_Slt)];
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Draw analysis
    if opt.draw
        
        plot(startTimes, y, 'parent',ax(i))
        title(strrep(neuralDirs(i).name,'_',' '))
        xlabel('Trial Start Time (s)')
        ylabel('y')

        % Draw across channel plot
        p(i) = plot(startTimes_flt, yS,'LineWidth',1,'parent',ax(3));      
        plot(ax(3).XLim,[stdThreshold stdThreshold],'color',p(i).Color)
        xlabel('Trial Start Time (s)')
        ylabel('Std')
        drawnow

        % Draw mean variance
%         plot([min(startTimes_flt) max(startTimes_flt)],...
%               repmat(median(yS),2,1),'--o','color',color{i},'LineWidth',1)

        % Draw Filtered PSTHs        
        oriFig(i) = drawFilteredPSTHs(neuralDirs(i).name,...
                                      binCenters, startTimes, nRate);

        fltFig(i) = drawFilteredPSTHs(neuralDirs(i).name,...
                                      binCenters, startTimes_Slt, nRate_Slt);
    end
                                  
     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Report problematic trials to command window
    if strcmp(opt.style, 'verbose') 
        
        fprintf('%s\n', neuralDirs(i).name) % report neural directory (to indicate hemisphere)

        for j = 1 : numel(maskIndex)   % For each problematic trial

            fprintf('T%03d\t',   maskIndex(j))
            fprintf('F1 %d\t',   B.data(maskIndex(j),strcmp(B.colheaders,'F1')));
            fprintf('F0 %d\t',   B.data(maskIndex(j),strcmp(B.colheaders,'Pitch')));
            fprintf('Attn %d\t', B.data(maskIndex(j),strcmp(B.colheaders,'Atten')));        
            fprintf('Side %d\t', B.data(maskIndex(j),strcmp(B.colheaders,'Side')));
            fprintf('Resp %d\n', B.data(maskIndex(j),strcmp(B.colheaders,'Response')));
        end    
    end    
end

% Link analytic plots
if opt.draw
    linkaxes(ax(1:2),'y')
    linkaxes(ax,'x')
end
% 
% % Create save directory
% saveDir = fullfile( strrep(ferDir,'testData','testResults'),... % Generic path
%                     strrep(bFile,'.txt',''));                   % Session specific folder                
% mkdir(saveDir)        
% 
% % Save figures
% saveas(fltFig(1), fullfile(saveDir,'SU2_filtered.fig'))
% saveas(fltFig(2), fullfile(saveDir,'SU3_filtered.fig'))
% saveas(oriFig(1), fullfile(saveDir,'SU2_original.fig'))
% saveas(oriFig(2), fullfile(saveDir,'SU3_original.fig'))
% saveas(f1,        fullfile(saveDir,'Per channel.fig'))
% saveas(f2,        fullfile(saveDir,'Cross channel Stdev.fig'))
% 
% % Close figures
% close([ oriFig' fltFig' f1 f2])




function pFig = drawFilteredPSTHs(figName, x, y, z)

pFig = figure('name',figName,'color','w',...
              'units','normalized','position',[0.05 0.05 0.9 0.7]);

colormap(cubehelix)


% Define channel mapping
chanMap = transpose( [14 13 12 11;
                      15 04 05 10;
                      16 03 06 09;
                      02 01 08 07]);
% For each channel
for j = 1 : 16

 % Specify channel
 chan = chanMap(j);
 subplot(4,4,j)

 % Add PSTH 
 imagesc(x,y,z{j})

 % Format
 axis tight
 title( sprintf('C%02d',chan))

 if chan == 2;               % Add axes labels
     xlabel('Time after onset(s)')
     ylabel('Stim Time (s)')
 end
end