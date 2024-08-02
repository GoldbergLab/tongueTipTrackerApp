function t_stats = add_SSM_dur(t_stats)
% adds SSM durations to t_stats in t_stats_path

% Note that all the cellfun business is to correctly handle empty entries
% for SSM_start or SSM_end, which can be generated, for example, by
% placeholder licks.

SSM_start = {t_stats.SSM_start};
SSM_end = {t_stats.SSM_end};
SSM_dur = cellfun(@(e, s)e-s, SSM_end, SSM_start, 'UniformOutput', false);
[t_stats(:).SSM_dur] = SSM_dur{:};
%save(t_stats_path, 't_stats');

end