function [t_stats] = assign_laser_2D(t_stats, xml_dir)

xml_file = rdir(append(xml_dir, '*\*.xml'));

if isempty(xml_file)
    error('No xml files found in %s', xml_dir);
end

laser_2D = zeros(numel(t_stats), 1);

for i = 1:max([t_stats.trial_num])
    laser = [t_stats([t_stats.trial_num] == i).laser];
    time_rel_cue = [t_stats([t_stats.trial_num] == i).time_rel_cue];
    % calculate lick indeces relative to 1st spout contact
    if sum(laser) > 0
        laserFrames = findLaserFrames(xml_file(i).name, [], true);
        [laserOn, laserOff] = findOnsetOffsetPairs([], laserFrames, true);
%        [laserOn, laserOff] = findLaserOnLaserOff(xml_file(i).name);
        laser_2D_temp = time_rel_cue > laserOn & time_rel_cue < laserOff;
        laser_2D([t_stats.trial_num] == i) = laser_2D_temp;
    else
        % do nothing, as it should be zeros
    end
end

laser_2D = num2cell(laser_2D);

[t_stats(:).laser_2D] = laser_2D{:};

function [laserOn, laserOff] = findLaserOnLaserOff(xmlFilepath)
text = fileread(xmlFilepath);
laser_text = regexp(text, 'E</Time>');
if laser_text
    laserOn = regexp(text((laser_text(1)-30):laser_text(1)), '"([0123456789]+)"', 'tokens');
    laserOff = regexp(text((laser_text(end)-30):laser_text(end)), '"([0123456789]+)"', 'tokens');
    laserOn = str2num(laserOn{1}{1});
    laserOff = str2num(laserOff{1}{1});
else
    disp('Error!  No laser tag present in xml file')
    laserOn = [];
    laserOff = [];
end
end

end