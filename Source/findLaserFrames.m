function laserOnFrames = findLaserFrames(xmlFilepath, xmlText, filter, queue)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% findLaserFrames: Find laser on frames from a video XML file
% usage:  laserFrames = findLaserFrames(xmlFilepath)
%         laserFrames = findLaserFrames([], xmlText)
%
% where,
%    xmlFilepath is a char array containing a filepath to a video XML file
%    xmlText is a char array containing the text in a video XML file
%    filter is an optional boolean indicating whether or not to attempt to
%       filter the laser signal for spurious signals, and heal single-frame
%       gaps. Default is true.
%    queue is an optional parallel pool data queue, used to communicate
%       messages to the user in a parallel process. If omitted or empty, 
%       output is simply printed to the MATLAB terminal.
%    laserFrames is an array of frame numbers corresponding to valid laser
%       on frames.
%
% If xmlText is not provided, then the XML file is loaded from xmlFilepath.
%   Either xmlText or xmlFilepath must be provided. If you want the error 
%   messages to include the correct xmlFilepath, you must provide it 
%   instead of or in addition to xmlText.
% This function performs some sanity checks and filtering on the laser on
%   frames due to known past issues with the laser on signal. It ignores
%   single-frame laser on pulses, as well as single frame gaps in the laser
%   on signal, as those are known to be spurious. It also ignores laser on
%   pulses before frame #1, as pre-cue laser on is spurious.
%
% See also: labelTrialsWithCueAndLaser
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('filter', 'var') || isempty(filter)
    filter = true;
end
if ~exist('queue', 'var') || isempty(queue)
    queue = parallel.pool.DataQueue();
    afterEach(queue, @disp);
end

if isempty(xmlText)
    % Read XML file as text
    xmlText = fileread(xmlFilepath);
end

if isempty(xmlFilepath)
    name = '<filename not provided>';
    ext = '';
else
    [~, name, ext] = fileparts(xmlFilepath);
end

% Find list of laser on frame numbers
laserFrameTokens = regexp(xmlText, '<Time frame=\"(-?[0-9])+\">[0-9\.\ \:]+ E</Time>', 'tokens');
laserOnFrames = sort(cellfun(@(f)str2double(f{1}), laserFrameTokens));

% Alert user to potential abnormalities in laser on signal, and attempt to
% compensate for them.
if any(diff(laserOnFrames) ~= 1)
    send(queue, sprintf('Warning, file %s has multiple laser-on pulses!', [name, ext]));
end
if any(laserOnFrames < 1)
    send(queue, sprintf('Warning, file %s has laser-on pulses before the cue frame! Ignoring laser signal before cue frame...', [name, ext]));
end
if length(laserOnFrames) == 1
    send(queue, sprintf('Warning, file %s has only one single frame of post-cue laser-on pulse!.', [name, ext]));
end

if filter
    laserOnFrames(laserOnFrames < 1) = [];

    % Find # of laser on neighbors for each laser off frame
    laserMask = false(1, max(laserOnFrames));
    laserMask(laserOnFrames) = true;
    laserNeighbors = conv(laserMask, [1, 1, 1], 'same');
    laserOffNeighbors = laserNeighbors(~laserMask);
    % Determine if there are any single-frame isolated laser-off signals
    if any(laserOffNeighbors >= 2)
        % There are isolated single-frame laser-offs...
        send(queue, sprintf('Warning, file %s has isolated single-frame laser-offs! Eliminating them...', [name, ext]));
        laserOffFrames = find(~laserMask);
        laserOnFrames = sort([laserOnFrames, laserOffFrames(laserOffNeighbors >= 2)]);
    end
    % Find # of laser on neighbors for each laser on frame
    laserMask = false(1, max(laserOnFrames));
    laserMask(laserOnFrames) = true;
    laserNeighbors = conv(laserMask, [1, 1, 1], 'same');
    laserOnNeighbors = laserNeighbors(laserMask);
    % Determine if there are any single-frame isolated laser-on signals
    if any(laserOnNeighbors < 2)
        % There are isolated single-frame laser-ons...
        send(queue, sprintf('Warning, file %s has isolated single-frame laser-ons!', [name, ext]));
        laserOnFrames(laserOnNeighbors < 2) = [];
    end
end