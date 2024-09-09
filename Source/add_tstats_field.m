function t_stats = add_tstats_field(t_stats, fieldname, value, options)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% add_tstats_field: Add a field to a t_stats file
% usage:  [t_stats] = add_tstats_field(t_stats, fieldname, value, Name/Value, ...)
%
% where,
%    t_stats is the given t_stats file
%    fieldname is the name of the field to add to the t_stats file
%    value is the value to initialize the new field to
%    Name/Value arguments can include:
%       MatchFieldShape: The name of an existing field in t_stats that
%           should be used to determine the shape of the value put into 
%           each element of the new field. If provided, the given value 
%           must be a scalar, and will be repeated to form an array of the 
%           matching shape. The first row of the given t_stats will be used
%           to determine the shape.
%
% This function is designed to easily and safely add a new field to an
%   existing t_stats data structure.
%
% See also: make_t_struct
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

arguments
    t_stats struct
    fieldname char {mustNotBeFieldOf(fieldname, t_stats)}
    value
    options.MatchFieldShape char {mustBeFieldOf(options.MatchFieldShape, t_stats)}
end

if isfield(t_stats, fieldname)
    error('Fieldname %s already exists', fieldname);
end

if isfield(options, 'MatchFieldShape')
    % Change shape of value to match a particular field
    if ~isscalar(value)
        error('If MatchFieldShape argument is provided, the given value must be a scalar')
    end
    if isempty(t_stats)
        error('If MatchFieldShape argument is provided, t_stats cannot be empty')
    end
    value = repmat(value, size(t_stats(1).(options.MatchFieldShape)));
end

[t_stats.(fieldname)] = deal(value);