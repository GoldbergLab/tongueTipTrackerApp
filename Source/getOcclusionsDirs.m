function [occlusion_reports_dir, occlusion_originals_dir, overwrite_warning] = getOcclusionsDirs(root_path)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% getOcclusionDirs: Get directories for occlusion reports and originals
% usage:  [occlusion_reports_dir, occlusion_originals_dir, overwrite_warning] 
%               = getOcclusionsDirs(root_path)
%
% where,
%    root_path is the path to the directory to get the occlusions and
%       originals directories from.
%    occlusion_reports_dir is the correct directory to store occlusion
%       reports in. If it doesn't exist, it will be created. If it exists, 
%       and it already contains files that appear to be occlusion reports,
%       overwrite_warning will be true.
%    occlusion_originals_dir is the correct directory to store original 
%       masks in. If it doesn't exist, it will be created. If it exists, 
%       and it already contains files that appear to be tongue masks,
%       overwrite_warning will be true.
%    overwrite_warning is a boolean flag indicating whether or not
%       occlusion reports or original masks are already in their respective
%       directories.
%
% This function takes a root path containing tongue masks to be checked and
%   healed for spout occlusions, and finds or creates appropriate
%   subdirectories for storing occlusion reports and original (unhealed)
%   masks. If those directories exist and already contain reports or masks,
%   overwrite_warning is true, so the user can decide whether or not to
%   continue.
%
% See also: heal_occlusion, heal_occlusion_trial, heal_occlusion_sesesion,
%   tongueTipTrackerApp
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Set up occlusion reports directory to hold occlusion reports
occlusion_reports_dir = fullfile(root_path, 'occlusion_reports');
if exist(occlusion_reports_dir, 'dir')
    report_file_paths = findFilesByRegex(occlusion_reports_dir, '(Bot)|(Top)_[0-9]+_occ-report-[0-9]+\.mat', false, false);
    overwrite_report_warning = ~isempty(report_file_paths);
else
    mkdir(occlusion_reports_dir);
    overwrite_report_warning = false;
end

% Set up originals_dir directory to hold original masks
occlusion_originals_dir = fullfile(root_path, 'occlusion_originals');
if exist(occlusion_originals_dir, 'dir')
    original_file_paths = findFilesByRegex(occlusion_originals_dir, '(Bot)|(Top)_[0-9]+.mat', false, false);
    overwrite_original_warning = ~isempty(original_file_paths);
else
    mkdir(occlusion_originals_dir);
    overwrite_original_warning = false;
end

overwrite_warning = overwrite_report_warning || overwrite_original_warning;
