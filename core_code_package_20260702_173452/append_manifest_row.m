function append_manifest_row( ...
    manifest_fid, key, class_name, class_name_zh, ...
    wav_path, json_path, meta)
%APPEND_MANIFEST_ROW Append one completed sample to the dataset manifest.

if isfield(meta, 'original_metadata')
    old = meta.original_metadata;
else
    old = meta;
end

design_vec = [old.line_spectrum.lines.design_line_snr_db];
measured_vec = [old.line_spectrum.lines.measured_line_snr_db];
measured_vec = measured_vec(isfinite(measured_vec));

if isempty(measured_vec)
    mean_measured_snr = NaN;
else
    mean_measured_snr = mean(measured_vec);
end

fprintf(manifest_fid, ['%s,%s,%s,%s,%s,%d,%.6f,%.6f,%d,%.6f,%.6f,' ...
    '%.6f,%.6f,%.6f,%d,%.6f,%.6f\n'], ...
    key, class_name, class_name_zh, wav_path, json_path, ...
    old.fs, old.duration_sec, old.continuous_spectrum.SPL1K_db, ...
    old.propeller.blade_number, old.propeller.shaft_freq_hz, ...
    old.propeller.blade_freq_hz, old.geometry.tx_depth_m, ...
    old.geometry.rx_depth_m, old.geometry.distance_km, ...
    old.line_spectrum.num_lines, mean(design_vec), mean_measured_snr);

end