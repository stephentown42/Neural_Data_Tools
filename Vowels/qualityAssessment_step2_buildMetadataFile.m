function qualityAssessment_step2_buildMetadataFile

% Define paths
dirs.home  = Cloudstation('Vowels\Spatial_Unmasking');
dirs.behav = fullfile(dirs.home,'Behavior');
dirs.MClus = 'C:\Analysis\Portable MClust Events AlignedInterpolated';
dirs.save  = fullfile(dirs.home,'\Ephys\QualityAssessment');

% Create metadata file
fid = fopen( fullfile(dirs.save,'QA_session_metadata.txt'),'wt+');

% Print headers
fprintf(fid,'Ferret\tSession\tEventExtraction\tLeft\tRight\n');
        
% List subjects
ferrets = dir( fullfile( dirs.behav, 'F*'));

% For each subject
for i = 1 : numel(ferrets)

    % List behavioral files
    dirs.ferret = fullfile(dirs.behav, ferrets(i).name);
    bFiles = dir( fullfile(dirs.ferret, '*Block*.txt'));
    
    % For each behavioral file
    for j = 1 : numel(bFiles)

        % Report metadata
        fprintf(fid, '%s\t%s\t', ferrets(i).name, bFiles(j).name);    
        
        % Get event time directories
        dirs.ev = dir( fullfile(dirs.MClus, strrep(bFiles(j).name,'.txt','*')));
        
        % Report extraction
        if numel(dirs.ev) == 0
            fprintf(fid,'0\n');
        else
            fprintf(fid,'1\n');
        end        
                                
    end
end

fclose(fid);

