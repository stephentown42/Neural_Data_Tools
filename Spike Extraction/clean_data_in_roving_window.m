function output = clean_data_in_roving_window(data, windowTime, fS)
%
% data - matrix of ephys data (rows = channels, columns = samples)
% windowLen - time window in seconds for cleaning (default = 5)
%
% The function assumes that the 1/2 second at the start and end of the
% cleaned data are dubious (which is reasonable)

try

% Default arguments
if nargin < 3
    fS = 20000; % Hz
end

if nargin == 1
    windowTime = 5;  % Seconds    
end

if windowTime <= 1
   error('Increase window time to > 1 second') 
end

% Preassign output
output = data;

% Compute sample sizes
total_samps = size(data, 2);
window_samps = round( fS * windowTime);
edge_samps = round(fS)/2;
sample_int = window_samps - fS;

% t_start = tic;
h = waitbar(0);

% For roving window
for i = 1 : sample_int :  total_samps
    
    % Report progress
    waitbar( 100 * (i / total_samps), h)
%     fprintf('Cleaning: %.1f%% Complete\n', 100 * (i / total_samps))
    
    % Clean data
    idx = i : i + window_samps;   
    idx(idx > total_samps) = [];    
    raw_data = data(:, idx);    
    cleaned_data = CleanData( raw_data, 0);
    
    % Remove edges
    idx = edge_samps : (window_samps - edge_samps);
    idx(idx >= size(cleaned_data, 1)) = [];
    cleaned_data = transpose( cleaned_data(idx, 1:end-2));
    
    % Return
    idx = idx + i;
    idx(idx > total_samps) = [];
    output(:, idx) = cleaned_data;
end

% fprintf('Cleaning complete: %.3f seconds\n', toc(t_start))
close(h)

catch err
    err
    keyboard
end