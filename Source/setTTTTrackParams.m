function params = setTTTTrackParams(im_shift)
% Set up tip tracking parameters to be the defaults for tongueTipTrackerApp
% The resulting parameter struct is designed to be used in tongueTipTracker.m

params.N_pix_min = 100;
params.figPosition = [1921, 41, 1920, 963];
params.im_shift = im_shift;
params = setTrackParams(params);
