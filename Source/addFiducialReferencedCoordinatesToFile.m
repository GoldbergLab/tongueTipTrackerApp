function t_stats = addFiducialReferencedCoordinatesToFile(t_stats_file, fiducialPoint, overwrite)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% addFiducialReferencedCoordinatesToFile: Take a mouse tongue kinematics
%   t_stats.mat file and add in fiducial-referenced coordinates.
% usage:  t_stats = addFiducialReferencedCoordinates(t_stats, fiducialPoint)
%
% where,
%    t_stats_file is a path to a t_stats file
%    fiducialPoint is a 1x3 vector representing the 3D coordinates of the
%       fiducial point, in the order (ML, AP, DV)
%    overwrite is an optional boolean flag. If true, it will simply
%       overwrite the t_stats file. If false (default), it will first copy
%       the t_stats file to a new name before saving the modified struct.
%    t_stats is the modified structure, output for convenience.
%
% A "t_stats" file, which contains all kinematic measurements of a mouse
%   tongue in a session organized by lick, contains only coordinates
%   referenced to the top left corner of the mask image for the top and
%   bottom views of the tongue. This function adds anatomical 
%   fiducial-referenced coordinates to the t_stats file.
%
% See also: tongueTipTrackerApp, addFiducialReferencedCoordinates
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('ovewrite', 'var')
    overwrite = false;
end

if ~overwrite
    % First copy t_stats file to a backup (append "_without_fiducial" to name)
    [path, name, ext] = fileparts(t_stats_file);
    backup_t_stats_file = fullfile(path, ['no-fiducial_', name, ext]);
    copyfile(t_stats_file, backup_t_stats_file);
end

% Load t_stats struct from file, and other stuff that gets saved with it.
S = load(t_stats_file, 't_stats', 'streak_on', 'streak_off');

% Handle case where streak_on and streak_off aren't saved with t_stats struct
if ~isfield(S, 'streak_on')
    S.streak_on = [];
end
if ~isfield(S, 'streak_off')
    S.streak_off = [];
end

% If it doesn't have a t_stats struct, we're done.
if ~isfield(S, 't_stats')
    error('Provided file does not contain a struct called ''t_stats''');
end

% Add fiducial-referenced variables to t_stats struct
t_stats = addFiducialReferencedCoordinates(S.t_stats, fiducialPoint);
streak_on = S.streak_on;
streak_off = S.streak_off;

% Save modified t_stats struct to file
save(t_stats_file, 't_stats', 'streak_on', 'streak_off');