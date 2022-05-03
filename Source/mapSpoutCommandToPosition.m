function t_stats = mapSpoutCommandToPosition(t_stats, spoutCalibration)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% mapSpoutCommandToPosition: Map the spout motor commands to a pixel
%   position in video.c
% usage:  t_stats = mapSpoutCommandToPosition(t_stats, spoutCalibration)
%
% where,
%    t_stats is a t_stats file that has already been aligned to FPGA data.
%    spoutCalibration is a structure containing a mapping between motor
%       command space and video pixel space. It should have the following
%       structure:
%       spoutCalibration
%           .x(1)  = <x pixel coordinate for spout in initial position>
%           .x(2)  = <x pixel coordinate for spout in next position>
%               ...
%           .x(N)  = <x pixel coordinate for spout in Nth position>
%           .y(1)  = <y pixel coordinate for spout in initial position>
%           .y(2)  = <y pixel coordinate for spout in next position>
%               ...
%           .y(N)  = <y pixel coordinate for spout in Nth position>
%           .z(1)  = <z pixel coordinate for spout in initial position>
%           .z(2)  = <z pixel coordinate for spout in next position>
%               ...
%           .z(N)  = <z pixel coordinate for spout in Nth position>
%           .speed = <speed of motor in pixels / ms in bottom mask>
%           .latency = <latency from motor command to movement initiation in ms>
%
%   The following fields get added in this function:
%           .cx(1) = <x command value for spout in initial position>
%           .cx(2) = <x command value for spout in next position>
%               ...
%           .cx(N) = <x command value for spout in Nth position>
%           .cy(1) = <y command value for spout in initial position>
%           .cy(2) = <y command value for spout in next position>
%               ...
%           .cy(N) = <y command value for spout in Nth position>
%           .cz(1) = <z command value for spout in initial position>
%           .cz(2) = <z command value for spout in next position>
%               ...
%           .cz(N) = <z command value for spout in Nth position>
%           .x_map = function that takes an x command and outputs the
%                       corresponding x position
%           .y_map = function that takes an y command and outputs the
%                       corresponding y position
%           .z_map = function that takes an z command and outputs the
%                       corresponding z position
%
% This function takes a t_stats struct that has already been aligned and
%   combined with FPGA data, and adds in the spout position calculated 
%   based on the spout motor commands and a calibration mapping between 
%   spout motor command and spout position.
%
% See also: 
%
% Version: <version>
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Build vector of all commands in t_stats file
all_command_x = horzcat(t_stats.actuator_command_x);
all_command_y = horzcat(t_stats.actuator_command_y);
% There is no z motor currently, but we do need a z position, so we'll construct a vector of fake z commands.
all_command_z = 0*all_command_y;
% Remove NaN (NaN is placeholder for non-first-lick command vectors)
all_command = [all_command_x; all_command_y; all_command_z];
notNans = ~isnan(all_command_x);
all_command = all_command(:, notNans);
% Get unique command vectors, preserving order they were in during
% session. This should ensure "home" position command is 1st, followed
% by whichever target position command came first in the session, then
% any subsequent target position commands in order.
unique_actuator_commands = unique(all_command', 'row', 'stable')';
spoutCalibration.cx = unique_actuator_commands(1, :);
spoutCalibration.cy = unique_actuator_commands(2, :);
spoutCalibration.cz = unique_actuator_commands(3, :);

% Trim command and position vectors to same length
numXCalPoints = min([length(spoutCalibration.cx), length(spoutCalibration.x)]);
numYCalPoints = min([length(spoutCalibration.cy), length(spoutCalibration.y)]);
numZCalPoints = min([length(spoutCalibration.cz), length(spoutCalibration.z)]);
spoutCalibration.cx = spoutCalibration.cx(1:numXCalPoints);
spoutCalibration.cy = spoutCalibration.cy(1:numYCalPoints);
spoutCalibration.cz = spoutCalibration.cz(1:numZCalPoints);
spoutCalibration.x = spoutCalibration.x(1:numXCalPoints);
spoutCalibration.y = spoutCalibration.y(1:numYCalPoints);
spoutCalibration.z = spoutCalibration.z(1:numZCalPoints);

% Fit a line to the command/position mapping to get a general mapping
lmx = fitlm(spoutCalibration.cx, spoutCalibration.x);
lmy = fitlm(spoutCalibration.cy, spoutCalibration.y);
lmz = fitlm(spoutCalibration.cz, spoutCalibration.z);

spoutCalibration.x_map = @lmx.predict;
spoutCalibration.y_map = @lmy.predict;
spoutCalibration.z_map = @lmz.predict;

for lickNum = 1:length(t_stats)
    lickNum
    command_x = t_stats(lickNum).actuator_command_x;
    command_y = t_stats(lickNum).actuator_command_y;
    command_z = 0*command_y;
    if ~isempty(command_x) && ~isempty(command_y) && ~isempty(command_z) && ~isnan(command_x(1)) && ~isnan(command_y(1)) && ~isnan(command_z(1))
        % This must be lick #1, where the entire trial's actuator command
        % vector is stored.
        
        % Map command to position (note: there is no z command, so we're
        % making a fake one to match our calibration.
        t_stats(lickNum).spout_position_x = spoutCalibration.x_map(t_stats(lickNum).actuator_command_x')';
        t_stats(lickNum).spout_position_y = spoutCalibration.y_map(t_stats(lickNum).actuator_command_y')';
        t_stats(lickNum).spout_position_z = spoutCalibration.z_map(0*t_stats(lickNum).actuator_command_y')';
        % Interpolate position where there are sudden jumps.
        t_stats(lickNum).spout_position_x = inferPosition(t_stats(lickNum).spout_position_x, spoutCalibration.speed, spoutCalibration.latency);
        t_stats(lickNum).spout_position_y = inferPosition(t_stats(lickNum).spout_position_y, spoutCalibration.speed, spoutCalibration.latency);
        t_stats(lickNum).spout_position_z = inferPosition(t_stats(lickNum).spout_position_z, spoutCalibration.speed, spoutCalibration.latency);
    else
        t_stats(lickNum).spout_position_x = NaN;
        t_stats(lickNum).spout_position_y = NaN;
        t_stats(lickNum).spout_position_z = NaN;
    end
end

function position_interp = inferPosition(position, motorSpeed, motorLatency)
% position = a 1D vector of position values for the motor in units of Volts
% motorSpeed = a speed in units of pixels / ms, indicating how fast the
% motor can move.
t = 1:length(position);
% Shift position by motor latency
position = [position(1) * ones([1, motorLatency]), position];
position = position(1:length(t));
position_interp = position;
positionLength = length(position);
changePoints = find(diff(position) ~= 0);
for k = 1:length(changePoints)
    changePoint = changePoints(k);
    startPosition = position(changePoint);
    endPosition = position(changePoint+1);
    deltaX = endPosition - startPosition;
    moveTime = round(abs(deltaX)/motorSpeed);
    startInterp = changePoint+1;
    endInterp = min([changePoint+moveTime, positionLength]);
    position_interp(startInterp:endInterp) = NaN;
    interpIdx = isnan(position_interp);
    position_interp(interpIdx) = interp1(t(~interpIdx), position_interp(~interpIdx), t(interpIdx), 'pchip');
end