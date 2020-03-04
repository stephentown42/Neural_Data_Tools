function T = get_SRF_click_times(tank, block)
%
% Returns a table of click sound metadata containing:
% - event times according to TDT system (in seconds)
% - speaker channel on which events occured
%
% 4th Feb 2020 - Stephen Town

if nargin == 0
   
    full_path = uigetdir('E:\UCL_Behaving');
    [tank, block] = fileparts(full_path);
end

% Sounds presented across 12 speakers, with output saved in three stores
% each continaing 4 channels of stimulus output
stores = {'S1-4', 'S5-8', 'S912'};
spkr = reshape(1 : 12, 4, 3);
[ev_time, ev_spkr] = deal( cell(3,1));

% For each store
for i = 1 : 3
    
    % Load data
    data = TDT2mat( tank, block, 'STORE', stores{i});
    
    if isempty(data.streams)
        error('Block does not contain %s', stores{i})
    end
   
    store_name = fieldnames(data.streams);
    eval( sprintf('fS = data.streams.%s.fs;', store_name{1}));
    eval( sprintf('data = data.streams.%s.data;', store_name{1}));
    
    % Threshold signals
    data = data > 0;   
    [ev_chan, ev_samp] = ind2sub( size(data), find(data));
    
    % Quality control    
    nEvents = sum(data, 2); 
    event_rate = nEvents ./ (nSamps/fS);
    if any(event_rate) > 1
        warning('High event rates detected');
    end
    
    % Select only threshold crossings
    ev_int = [inf; diff(ev_samp)];
    rm_idx = ev_int == 1;
    ev_samp(rm_idx) = [];
    ev_chan(rm_idx) = [];
        
    ev_time{i} = ev_samp ./ fS;
    ev_spkr{i} = spkr(ev_chan, i);    
end

T = table( cell2mat(ev_spkr), cell2mat(ev_time),...
    'variableNames',{'Speaker','Time'});