function write_json(json_path, meta)
%WRITE_JSON Write a MATLAB struct as UTF-8 JSON.

try
    json_text = jsonencode(meta, 'PrettyPrint', true);
catch
    json_text = jsonencode(meta);
end

json_text = restore_schema_nulls(json_text);

fid = fopen(json_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('Cannot open json file: %s', json_path);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, json_text, 'char');

end

function json_text = restore_schema_nulls(json_text)
json_text = strrep(json_text, '"speed_kt": []', '"speed_kt": null');
json_text = strrep(json_text, '"water_depth_m": []', '"water_depth_m": null');
json_text = strrep(json_text, '"latitude_deg": []', '"latitude_deg": null');
json_text = strrep(json_text, '"longitude_deg": []', '"longitude_deg": null');
json_text = strrep(json_text, '"month": []', '"month": null');
end