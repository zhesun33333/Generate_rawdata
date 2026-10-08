function ensure_dir(path)
%ENSURE_DIR 若文件夹不存在，则创建。
if ~exist(path, 'dir')
    mkdir(path);
end
end
