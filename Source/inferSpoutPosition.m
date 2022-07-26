function position_interp = inferSpoutPosition(position, motorSpeed, motorLatency)
% position = a 1D vector of position values for the motor in units of Volts
% motorSpeed = a speed in units of pixels / ms, indicating how fast the
% motor can move.
t = 1:length(position);
% Shift position by motor latency
position = [position(1) * ones([1, motorLatency]), position];
position = position(1:length(t));
position_interp = position;
positionLength = length(position);
changePoints = find(diff(position) ~= 0);
for k = 1:length(changePoints)
    changePoint = changePoints(k);
    startPosition = position(changePoint);
    endPosition = position(changePoint+1);
    deltaX = endPosition - startPosition;
    moveTime = round(abs(deltaX)/motorSpeed);
    startInterp = changePoint+1;
    endInterp = min([changePoint+moveTime, positionLength]);
    position_interp(startInterp:endInterp) = NaN;
    interpIdx = isnan(position_interp);
    position_interp(interpIdx) = interp1(t(~interpIdx), position_interp(~interpIdx), t(interpIdx), 'pchip');
end