function saveOcclusionResults(report_data, healed_masks, save_dir, occlusions_dir, originals_dir, view, heal_timestamp, original_mask_path, trial_idx, save_original)
% report_data =         struct containing occlusion report for each frame
% healed_masks =        healed mask stack to save
% save_dir =           directory in which to save healed masks and report
% occlusions_dir =      directory in which to move original unhealed masks
% originals_dir =       directory where originals were moved for backup
% view =                view name (either "Top" or "Bot")
% heal_timestamp =      timestamp indicating when healing was done
% original_mask_path =  path to where mask stack was originally stored (now
%                       may contain patched masks)
% trial_idx =           trial index (in 1-indexed numbering)
% save_original         optional boolean flag - copy original mask before
%                       altering?

trial_num = trial_idx - 1;

if isempty(report_data)
    return;
end

% Determine path to move original mask stack file to, to avoid overwriting
% it
[~, original_name, original_ext] = fileparts(original_mask_path);
moved_mask_path = fullfile(originals_dir, [original_name, original_ext]);

% Store info in struct fields
report.view = view;
report.heal_timestamp = heal_timestamp;
report.patched_mask_path = original_mask_path;
report.unmodified_mask_path = moved_mask_path;
report.trial_num = trial_num;
report.trial_idx = trial_idx;
report.data = report_data;
healed_name = sprintf('%s_%03d.mat', view, trial_num);
num_patched = sum([report_data.patch_size] > 0);
report.num_patched = num_patched;
report_name = sprintf('%s_%03d_occ-report-%04d.mat', view, trial_num, num_patched);

if save_original
    % Copy original mask stack to originals folder in case we want to revert.
    copyfile(original_mask_path, moved_mask_path);
end

% Save occlusion report
save(fullfile(occlusions_dir, report_name), 'report');

% Save healed masks
mask_pred = healed_masks;  % Legacy naming scheme which code depends on
save(fullfile(save_dir, healed_name), 'mask_pred');
