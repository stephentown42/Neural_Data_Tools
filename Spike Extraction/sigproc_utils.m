classdef sigproc_utils
   
    methods(Static)
        
        function data = load_neural_data(H5, str, chan)
        % function data = load_neural_data(H5, str, chan)
        % 
        % Find index for filtered neural data within H5 file structure and load
        %
        % Args:
        %     H5: hdf5 file object for reading in data
        %     str: name of stream to load in
        %     chan (optional): channel to load
        %
        % Returns:
        %     data: matrix of data with channels as rows and samples as columns

            % Assume all channels by default
            if nargin < 3
                chan = nan;
            end

            % Search metadata for analog stream with correct name
            h5_idx = 0;
            h5_ok  = false;

            while ~h5_ok && h5_idx < numel(H5.Recording{1}.AnalogStream)
                h5_idx    = h5_idx + 1;
                testLabel = H5.Recording{1}.AnalogStream{h5_idx}.Label;
                h5_ok     = contains(testLabel, str);
            end

            % Load data associated with the relevant stream, if found
            if h5_ok
                % Load all data
                if isnan(chan)
                    data = H5.Recording{1}.AnalogStream{h5_idx}.ChannelData;    
                else
                    data = H5.Recording{1}.AnalogStream{h5_idx}.ChannelData(chan,:);
                end
            else
                data = [];
                warning('Could not find requested stream')
            end
        end
                
        function [pxx, f, pxxc] = get_pwelch(x, fS, ov)
        % function [pxx, f, pxxc] = get_pwelch(x)
        %
        % Get power spectral density estimate for signal, including confidence
        % interval
        
            % Default overlap
            if nargin < 3
                ov = 0.1;    
            end
                
            % Define parameters for frequency range
            Nx = size(x, 2);        
            ns = floor(Nx);                                
            nff = max(256,2^nextpow2(fS));
            lsc = floor(fS);
            
            % Replace missing values
            if any(isnan(x))
               x = fillmissing(x,'linear','EndValues','nearest');
            end

            % Compute pWelch power spectral density
            [pxx, f, pxxc] = pwelch(x, lsc, floor(ov*lsc), nff, fS, 'ConfidenceLevel', 0.95);
            pxx = 10*log10(pxx);
        end
        
        function fig = plot_psd(f, pxx, pxxc)
        % function fig = plot_psd(f, pxx, pxxc)
        %
        % Plot power spectral density with confidence intervals
            
            fig = figure('nextplot','add');            

            plot(f,10*log10(pxxc),'--','color',[0.5 0.5 0.5 0.5])
            plot(f,pxx,'color','k')

            set(gca,'xscale','log')
            xlabel('Frequency (Hz)')
            ylabel('Magnitude (dB)')        
            grid
        end
        
        function nEv = get_peaks_n_troughs(pxx)
        % function get_peaks_n_troughs(pxx)
        %
        % Get the number of peaks and troughs in psd 
                                            
            pks = findpeaks(pxx,'MinPeakProminence',2);                 
            troughs = findpeaks(-pxx,'MinPeakProminence',2);                    
            nEv = numel(pks) + numel(troughs);
        end        
      
        function nEv = add_peaks_n_troughs(f, pxx)
        % function add_peaks_n_troughs(f, pxx)
        %
        % Label peaks and troughs in psd plot
                        
            hold on
        
            [pks, locs] = findpeaks(pxx,'MinPeakProminence',2);            
            scatter(f(locs), pks, 'markerfacecolor','r','marker','v',...
                'sizedata',10,'markeredgecolor','none');
            
            [troughs, trough_locs] = findpeaks(-pxx,'MinPeakProminence',2);        
            scatter(f(trough_locs), -troughs, 'markerfacecolor','c',...
                'marker','^','sizedata',10,'markeredgecolor','none');
            
            nEv = numel(pks) + numel(troughs);
        end
        
        function fig = peak_troughs_across_recording(fltData, fS)
        % function fig = peak_troughs_across_recording()
        %
        % Track peak/troughs over time
        
            time_window = 60; % Seconds        
            window_samps = floor(time_window * fS);
            n_windows = floor(size(fltData, 2) / window_samps);        

            win_data = reshape(fltData(1:window_samps*n_windows),...
                window_samps, n_windows);

            n_ev = nan(n_windows, 1);
            for i = 1 : n_windows            
                pxx = debug_utils.get_pwelch(win_data(:,i), fS, 0.5);
                n_ev(i) = debug_utils.get_peaks_n_troughs(pxx);
            end

            fig = figure;
            plot(n_ev)
        end
        
        function ind = find_large_amp_periods(x, fS, time_window, threshold)
        %function remove_large_amp_artefacts
        %
        % Remove portions of signal with large amplitudes indicative of
        % disconnection between headstage and electrode array
        % Get power in roving window
        %
        % Args:
        %   x: signal to clean
        %   fS: sample rate
        %   time_window: window in which to consider if artefact exists (in
        %                seconds)
        %   threshold: multiples of median threshold above which data is
        %              replaced with nans
        %
        % Returns:
        %   ind: indices of signal considered problematic
        
            % Check input data before doing anything else
            total_samps = size(x, 2);            
            if total_samps > intmax("uint64")
                error("Sample number cannot be represented using uint64")
            end           
        
            % Default settings
            switch nargin
                case 2
                    time_window = 3; % Seconds        
                    threshold = 2;   % Multiples of the median signal intensity
                case 3
                    threshold = 2; 
            end
            
            % Reshape data into segments with a standard length            
            window_samps = floor(time_window * fS / 2);
            n_windows = floor(total_samps / window_samps);
            checked_samps = window_samps*n_windows;
            
            x_win = reshape(x(1:checked_samps), window_samps, n_windows);
                
            % Calculate signal power in each segment 
            x_pow = sum(abs(x_win), 1);

            % Define threshold as multiple of median power across recording
            threshold = median(x_pow) * threshold;
            
            
            % Get indices of signal to drop (this could be more efficient)
            ind = reshape(uint64(1:checked_samps), window_samps, n_windows);
            ind = ind(:, x_pow > threshold);

            % Identify high-power samples and those in the remaining
            % section that were too long to 
            ind = [
                ind(:); 
                uint64(checked_samps+1:total_samps)'
                ];
            
        end
                
        function x = detect_power_loss(x, win_len)
        %
        % Removes data where there the rate of change in the signal is zero. A
        % completely flat trace will be turned into Nans while small variations at
        % turning points in true data should still contain enough noise not to be
        % removed unnecessarily
        %
        % For use with single unit electrophysiological data from multichannel systems
        % where zero values during disconnections distort statistics for spike
        % event detection (was previously detect_disconnections.m)
        %
        % Args:
        %   x: signal from which we remove constant signals
        %   win_length (optional): for use with single channel data
        %             period in which to look for zeros
        %
        % Returns:
        %   x: cleaned signal

            % For multiple channel data
            if all(size(x) > 1)

                % Sum across channels
                x2 = sum(x, 1);
                
                % Remove cases when the signal doesn't change between
                % samples (usually this will be a series of zeros, but
                % could be a constant non-zero value)
                ind = abs([inf diff(x2)]) == 0;
                x(:,ind) = nan;

                % Report to user
                pNan = 100 * sum(ind) / size(x, 2);
                fprintf('Static signal flagged for %.1f%% of signal\n', pNan)
            else        
                % Drop cases where the moving max and min are both zero
                x( movmax(x,win_len)== 0 & movmin(x,win_len)==0) = nan;    
            end
        end
   end
end


