function output_data = clean_peristimulus_data(data, trigTime, windowTime, fS)
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
%   Updated: 5th July 2020 - return nans for uncleaned samples
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
output_data = nan( nChan, nSamp);

% Compute sample windows
window_samps = ceil( windowTime * fS);

start_times = trigTime - (windowTime / 2);
start_times(start_times <= 0) = [];
start_times( isnan(start_times)) = [];
start_samp = round( start_times * fS);

idx = bsxfun(@plus, start_samp(:), 1:window_samps);

% Remove negative values
idx( any(idx < 1, 2), :) = [];
idx( any(idx > nSamp, 2), :) = [];

% t_start = tic;
h = waitbar(0, 'Cleaning data...');

% For each stimulus
for i = 1 : numel(start_samp)
    
    % Report progress
    waitbar( i / numel(trigTime), h)
    
    % Clean data           
    data_to_clean = data(:, idx(i,:));
    
    if any( isnan( data_to_clean(:))), continue; end
    
    cleaned_data = CleanData( data_to_clean, 0);
    output_data(:, idx(i,:)) = transpose( cleaned_data(:, 1:nChan));            
end

% fprintf('Cleaning complete: %.3f seconds\n', toc(t_start))
close(h)

catch err
    err
    keyboard
end