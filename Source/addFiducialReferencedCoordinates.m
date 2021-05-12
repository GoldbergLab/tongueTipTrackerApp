function t_stats = addFiducialReferencedCoordinates(t_stats, fiducialPoint)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% addFiducialReferencedCoordinates: Take a mouse tongue kinematics
%   t_stats struct and add in fiducial-referenced coordinates.
% usage:  t_stats = addFiducialReferencedCoordinates(t_stats, fiducialPoint)
%
% where,
%    t_stats is the t_stats data before and after adding new fields
%    fiducialPoint is a 1x3 vector representing the 3D coordinates of the
%       fiducial point, in the order (ML, AP, DV)
%
% A "t_stats" struct, which contains all kinematic measurements of a mouse
%   tongue in a session organized by lick, contains only coordinates
%   referenced to the top left corner of the mask image for the top and
%   bottom views of the tongue. This function adds anatomical 
%   fiducial-referenced coordinates to the t_stats struct.
%
% See also: tongueTipTrackerApp, addFiducialReferencedCoordinatesToFile
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Loop over t_stats struct array, adding new fiducial-referenced fields
for k = 1:length(t_stats)
    t_stats(k).tip_xf = t_stats(k).tip_x - fiducialPoint(1);
    t_stats(k).tip_yf = t_stats(k).tip_y - fiducialPoint(2);
    t_stats(k).tip_zf = t_stats(k).tip_z - fiducialPoint(3);

    t_stats(k).centroid_xf = t_stats(k).centroid_x - fiducialPoint(1);
    t_stats(k).centroid_yf = t_stats(k).centroid_y - fiducialPoint(2);
    t_stats(k).centroid_zf = t_stats(k).centroid_z - fiducialPoint(3);

end