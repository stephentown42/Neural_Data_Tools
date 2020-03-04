function quick_evoked_response_batch
%
%
% Batch wrapper to search for psths and generate if missing

% List paths
dirs.root = 'E:\MCS_DataManager_h5\Multi Channel Systems\Multi Channel Experimenter';
% dirs.root = 'E:\UCL_Behaving';
dirs.save = 'C:\Users\steph\Pictures';

% % List ferrets
% [nFerrets, ferrets] = nDir( dirs.root, 'F*');
% 
% % For each ferret
% for i = 1 : nFerrets
% 
%     % List blocks
%     dirs.ferret = fullfile( dirs.root, ferrets(i).name);
%     [nBlocks, blocks] = nDir( dirs.ferret, 'Block*');

    % For each block
%     for j = 1 : nBlocks
        
       % List H5 files
%        dirs.block = fullfile( dirs.ferret, blocks(j).name);
%        [nH5, h5_files] = nDir( dirs.block, '*.h5');
       [nH5, h5_files] = nDir( dirs.root, '*.h5');
         
       % For each file
       for k = 1 : nH5
           
           % Check if this file has already been drawn
           saveName = strrep( h5_files(k).name, '.h5','.png');     
           savePath = fullfile(dirs.save, saveName);
           
           if exist(savePath, 'file'), continue; end
           
           % Run main function
           fig = quick_evoked_response( dirs.root, h5_files(k).name);
%            fig = quick_evoked_response( dirs.block, h5_files(k).name);
           
           % Resize figure
           set(fig,'position',[0 1 50 25])
           
           % Print file to directory           
           myPrint( savePath, 'png', 300)   
           
           % Close figure
           close(fig)
       end
%     end
% end