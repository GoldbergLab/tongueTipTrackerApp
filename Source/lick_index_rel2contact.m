function [t_stats] = lick_index_rel2contact(t_stats)

%load(t_stats_path)

lick_index_contact1 = zeros(numel(t_stats), 1);
lick_index_contact2 = zeros(numel(t_stats), 1);

j = 0;
k = 0;
for i = 1:max([t_stats.trial_num])
    contact = [t_stats([t_stats.trial_num] == i).spout_contact];
    contact_ind = find(~isnan(contact), 2);
    
    % calculate lick indeces relative to 1st spout contact
    if isempty(contact_ind)
        lick_index_contact1(1+j:numel(contact)+j) = -(numel(contact)):1:-1;
        j = j + numel(contact);
    elseif contact_ind(1) == 1
        lick_index_contact1(contact_ind(1)+j:numel(contact)+j) = 1:numel(contact);
        j = j + numel(contact);
    elseif contact_ind(1) > 1
        lick_index_contact1(1+j:(contact_ind(1) - 1)+j) = -(contact_ind(1) - 1):1:-1;
        lick_index_contact1((contact_ind(1))+j:numel(contact)+j) = 1:(numel(contact) - (contact_ind(1) - 1));%(contact_ind(1) - 1):(numel(contact) - 1);
        j = j + numel(contact);
    end
    
    % calculate lick indeces relative to 2nd spout contact
    if isempty(contact_ind)
        lick_index_contact2(1+k:numel(contact)+k) = -(numel(contact)):1:-1;
        k = k + numel(contact);
    elseif numel(contact_ind) == 1
        lick_index_contact2(1+k:numel(contact)+k) = -(numel(contact)):1:-1;
        k = k + numel(contact);
    elseif contact_ind(2) > 1
        lick_index_contact2(1+k:(contact_ind(2) - 1)+k) = -(contact_ind(2) - 1):1:-1;
        lick_index_contact2((contact_ind(2))+k:numel(contact)+k) = 1:(numel(contact) - (contact_ind(2) - 1));%(contact_ind(1) - 1):(numel(contact) - 1);
        k = k + numel(contact);
    end
end

lick_index_contact1 = num2cell(lick_index_contact1);
lick_index_contact2 = num2cell(lick_index_contact2);

[t_stats(:).lick_index_contact1] = lick_index_contact1{:};
[t_stats(:).lick_index_contact2] = lick_index_contact2{:};

%save(t_stats_path, 't_stats')


    