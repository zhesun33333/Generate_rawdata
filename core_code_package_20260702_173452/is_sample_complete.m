function complete = is_sample_complete(wav_path, json_path)
%IS_SAMPLE_COMPLETE Check that both output files exist and JSON is valid.

wav_info = dir(wav_path);
json_info = dir(json_path);
complete = ~isempty(wav_info) && wav_info.bytes > 44 && ...
    ~isempty(json_info) && json_info.bytes > 2;

if complete
    try
        jsondecode(fileread(json_path));
    catch
        complete = false;
    end
end

end
