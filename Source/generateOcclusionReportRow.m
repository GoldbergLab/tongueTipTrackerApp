function report = generateOcclusionReportRow(frame_num, tongue_size, patch_size, spout_close)
% Generate one row (corresponding to view of one frame) in an occlusion report
% See also: heal_occlusion, heal_occlusion_trial

if nargin == 0
    % No arguments passed - generate an empty struct
    report = struct('frame', [], 'tongue_size', [], 'patch_size', [], 'spout_close', []);
    report = report([]);
    return;
end

% frame_num = number of the frame in question
% tongue_size = number of pixels within tongue
% patch_size = number of pixels within healed patch
% spout_close = whether or not the spout is close in this particular view
report.frame = frame_num;
report.tongue_size = tongue_size;
report.patch_size = patch_size;
report.spout_close = spout_close;