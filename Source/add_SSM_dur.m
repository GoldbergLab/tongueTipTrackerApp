function t_stats = add_SSM_dur(t_stats)
% adds SSM durations to t_stats in t_stats_path

SSM_start = [t_stats.SSM_start];
SSM_end = [t_stats.SSM_end];
SSM_dur = SSM_end - SSM_start;
SSM_dur = num2cell(SSM_dur);
[t_stats(:).SSM_dur] = SSM_dur{:};
%save(t_stats_path, 't_stats');

end