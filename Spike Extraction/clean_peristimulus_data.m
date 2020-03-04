function data = clean_peristimulus_data(data, trigTime, windowTime, fS)
%
% data - matrix of ephys data (rows = channels, columns = samples)
% windowLen - time window in seconds for cleaning (default = 5)
%
% The function assumes that the 1/2 second at the start and end of the
% cleaned data are dubious (which is reasonable)
%
% Only cleans neural data surrounding an event (e.g. stimulus presentation)
% in order to save time analysing 
%
% Stephen Town: 25th Feb 2020

try

% Default arguments
if nargin < 4
    fS = 20000; % Hz
end

if nargin < 3
    windowTime = 5;  % Seconds    
end

if windowTime <= 1
   error('Increase window time to > 1 second') 
end

% Replace nans with zeros to avoid errors
data( isnan( data)) = 0;
data( isinf( data)) = 0;
[nChan, nSamp] = size(data);

% Compute sample windows
window_samps = ceil( windowTime * fS);
window_idx = 1 : window_samps;
window_idx = window_idx - floor( window_samps / 2);

start_times = trigTime - windowTime / 2;
start_times(start_times <= 0) = [];
start_samp = round( start_times * fS);

idx = bsxfun(@plus, start_samp(:), window_idx);

% Remove negative values
idx( any(idx < 1, 2), :) = [];
idx( any(idx > nSamp, 2), :) = [];

% t_start = tic;
h = waitbar(0);

% For each 
for i = 1 : size(idx, 1)
    
    % Report progress
    waitbar( 100 * (i / numel(trigTime)), h)
    
    % Clean data           
    data_to_clean = data(:, idx(i,:));
    
    if any( isnan( data_to_clean(:))), continue; end
    
    cleaned_data = CleanData( data_to_clean, 0);
    data(:, idx(i,:)) = transpose( cleaned_data(:, 1:nChan));            
end

% fprintf('Cleaning complete: %.3f seconds\n', toc(t_start))
close(h)

catch err
    err
    keyboard
end