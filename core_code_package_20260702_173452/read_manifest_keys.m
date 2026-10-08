function keys = read_manifest_keys(manifest_path)
%READ_MANIFEST_KEYS Read existing sample keys from a dataset manifest.

keys = containers.Map('KeyType', 'char', 'ValueType', 'logical');
if exist(manifest_path, 'file') ~= 2
    return;
end

lines = readlines(manifest_path);
if numel(lines) <= 1
    return;
end

data_lines = lines(2:end);
data_lines = data_lines(strlength(strtrim(data_lines)) > 0);
for i = 1:numel(data_lines)
    comma_pos = strfind(char(data_lines(i)), ',');
    if ~isempty(comma_pos)
        key = char(extractBefore(data_lines(i), comma_pos(1)));
        keys(key) = true;
    end
end

end
