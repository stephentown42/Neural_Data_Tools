function x = detect_disconnections(x)
%
% Removes data where there the rate of change in the signal is zero. A
% completely flat trace will be turned into Nans while small variations at
% turning points in true data should still contain enough noise not to be
% removed unnecessarily
%
% For use with single unit electrophysiological data from multichannel systems
% where zero values during disconnections distort statistics for spike
% event detection

% Sum across channels (disconnections will happen on all channels, noise
% will be additive)
x2 = sum(x, 1);


x(:, abs([inf diff(x2)]) == 0) = nan;
