# 舰船辐射噪声源生成

入口为 `main_generate_dataset.m`，运行方式见[仓库说明](../README.md)。当前默认配置：

- 采样率 16,000 Hz，时长逐样本在 10–30 秒间采样。
- 水下目标、小渔船、货船、游轮、军舰，每类 16,000 条。
- 输出目录为当前工作目录下的 `ship_radiated_noise_dataset_toSZ/`。
- 每条样本写出 WAV 与 schema-v1 JSON，并更新 `manifest.csv`。
- 全数据集固定 `wav_scale = 1e-5`，使用 32 位 WAV；`save_components` 默认关闭。

`gen_ship_sample.m` 组合调制连续谱与线谱。`get_ship_configs.m` 定义类别参数。五类的局部线谱与连续谱之比均为 6–10 dB。轴频/叶频主调制系数为水下目标 0.06–0.08，军舰 0.10–0.12，其余三类 0.15–0.20。

`ship_metadata_to_schema_v1.m` 完成源元数据转换，原始参数保存在 `original_metadata`。`write_scaled_wav.m` 执行固定比例缩放与写盘。此阶段记录几何条件，传播处理由下游仓库完成。

小规模运行可先将入口中的 `num_each_class` 改为 1 或 2。本目录没有独立 demo 脚本。
