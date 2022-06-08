function text = generateFakeLaserXML(laserOnMask)
% Function to generate fake XML frame timing/laser char arrays to test the
% parsing utilities.

text = '';
pattern = '<Time frame="%d">%d:%d:%f%s</Time> ';

frameNum = 1;
for L = laserOnMask
    if L
        laserMark = ' E';
    else
        laserMark = '';
    end
    text = [text sprintf(pattern, frameNum, 11, 22, 33.4, laserMark)];
    frameNum = frameNum + 1;
end