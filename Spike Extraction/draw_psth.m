function draw_psth( file_name, spike_times, ev_times, chan_map)

    if nargin == 0       
        [file_name, path_name] = uigetfile('E:\UCL_Behaving', '*.mat'); 
        
        load( fullfile( path_name, file_name), 'spike_times', 'options')
        ev_times = options.stimTimes;
                
        chan_map_dir = 'C:\Users\steph\Documents';
        chan_map_file = 'Warp_to_WirelessHeadstage_ChanMap.txt';
        chan_map_path = fullfile( chan_map_dir, chan_map_file);
        chan_map = readtable( chan_map_path, 'delimiter','\t');
    end


    figure( 'name', ['PSTH: ' file_name],...
        'units','normalized',...
        'outerposition',[0 0 1 1]);

    nChans = numel( spike_times);
    sp = dealSubplots(4, nChans/4);
    bin_width = 0.01;
    psth_bins = -0.2 : bin_width : 0.8;
    
    for chan = 1 : nChans

        taso = bsxfun(@minus, spike_times{chan}, ev_times(:));
        nhist = histc( transpose(taso), psth_bins);
        nhist = nhist ./ bin_width;

        chan_idx = chan_map.MCS_Chan == chan;
        axes( sp( chan_map.Subplot_idx( chan_idx)))

        %             imagesc( psth_bins, 1:nStim, nhist')

        plotSE_patch( psth_bins, nhist', 'x', gca, 'k');

        xlabel('Time (s)')
        ylabel('Firing Rate (Hz)')

        warp_chan = chan_map.Warp_Chan( chan_idx);
        title(sprintf('E%02d', warp_chan))
    end