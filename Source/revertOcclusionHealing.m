function revertOcclusionHealing(root_path)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% revertOcclusionHealing: revert the directory after occlusion healing
% usage:  revertOcclusionHealing(root_path)
%
% where,
%    root_path is the path to the directory containing masks and directories
%       for occlusions reports and original masks.
%
% This function reverts the results of heal_occlusion_session on a
%   directory, restoring it to its original state.
%
% See also: heal_occlusion, heal_occlusion_trial, heal_occlusion_sesesion,
%   tongueTipTrackerApp
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Find the paths for the occlusion report and original mask directories
[occlusion_reports_dir, occlusion_originals_dir] = getOcclusionsDirs(root_path);

% Get a list of all occlusion report files
report_file_paths = findFilesByRegex(occlusion_reports_dir, '(Bot)|(Top)_[0-9]+_occ-report-[0-9]+\.mat', false, false);
% Loop over occlusion report files and delete them
for k = 1:length(report_file_paths)
    delete(report_file_paths{k});
end
fprintf('Deleted %d occlusion reports\n', length(report_file_paths));

% Get a list of all original mask files
original_file_paths = findFilesByRegex(occlusion_originals_dir, '(Bot)|(Top)_[0-9]+.mat', false, false);
% Loop over original masks and move them back to the root path (thus
% overwriting the patched masks)
for k = 1:length(original_file_paths)
    [~, original_name, original_ext] = fileparts(original_file_paths{k});
    movefile(original_file_paths{k}, fullfile(root_path, [original_name, original_ext]));
end
fprintf('Moved %d original masks back to root folder\n', length(original_file_paths));
