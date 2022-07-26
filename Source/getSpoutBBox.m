function spout_bbox = getSpoutBBox(lick_struct_row, spout_calibration, spout_width, mask_size)
% Return an array of one or more set of bbox coordinates from the
%   lick_struct row.
% spout_bbox will be Nx6, where N is the number of frames (milliseconds) in
%   the trial, such that spout_bbox(n, :) will return a 1x6  vector of the 
%   form [x0, y0, z0, sX, sY, sZ], where [x0, y0, z0] is the bottom back 
%   left corner of the spout, and sX, sY, and sZ are the size of the spout
%   bounding box in each dimension.
% spout_width is the width of the spout in pixels
% mask_size is a 1x3 array indicating the 3D size of the mask volume

% Map command to position (note: there is no z command, so we're
% making a fake one to match our calibration.
spout_position_x = spout_calibration.x_map(lick_struct_row.actuator1_ML_command')';
spout_position_y = spout_calibration.y_map(lick_struct_row.actuator2_AP_command')';
spout_position_z = spout_calibration.z_map(0*lick_struct_row.actuator2_AP_command')';
% Interpolate position where there are sudden jumps.
spout_position_x = inferSpoutPosition(spout_position_x, spout_calibration.speed, spout_calibration.latency);
spout_position_y = inferSpoutPosition(spout_position_y, spout_calibration.speed, spout_calibration.latency);
spout_position_z = inferSpoutPosition(spout_position_z, spout_calibration.speed, spout_calibration.latency);

x0 = round(spout_position_x' - spout_width);
y0 = spout_position_y';
z0 = spout_position_z';
sY = mask_size(2) - y0;
sX = spout_width*ones(size(sY));
sZ = spout_width*ones(size(sY));
spout_bbox = [x0, y0, z0, sX, sY, sZ];