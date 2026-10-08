# Generate_rawdata

UA-Bench 原始水声信号合成代码：检测脉冲、通信波形和舰船辐射噪声。

## 目录与入口

| 目录 | 入口 | 内容 |
| --- | --- | --- |
| `DataGen0608/` | `build_pure_pulse_dataset.m` | CW、LFM、HFM，共 80,000 条源波形 |
| `DataGen0608/` | `build_pure_comm_dataset.m` | 2FSK、4FSK、BPSK、QPSK、OFDM，每类 16,000 条 |
| `core_code_package_20260702_173452/` | `main_generate_dataset.m` | 五类舰船噪声，每类 16,000 条 |

采样率为 16 kHz。以上为当前脚本配置的生成数量。目录保留原始名称，辅助函数、历史实验脚本和已有水文输入一并保存。

这里生成的是传播前源波形。信道处理、QA 标注、划分筛选和评测框架位于 [underwater](https://github.com/zhesun33333/underwater)。

## 运行环境与入口

当前串行入口使用 GNU Octave 的 `argv()`。脚本包含 MATLAB 语法，但不应把这些入口当作未经修改即可运行的 MATLAB 脚本。

在安装 GNU Octave 及 signal、communications、image 包后，可从相应目录依次运行完整生成任务：

```sh
cd DataGen0608
octave --no-gui --eval "pkg load signal; pkg load communications; pkg load image; build_pure_pulse_dataset"
octave --no-gui --eval "pkg load signal; pkg load communications; pkg load image; build_pure_comm_dataset"
cd ../core_code_package_20260702_173452
octave --no-gui --eval "pkg load signal; main_generate_dataset"
```

先进行小规模检查时，将脉冲/通信入口的 `DEBUG_MAX_PER_BAND` 设置为 1 或 2，将舰船入口的 `num_each_class` 设置为 1 或 2。完整运行前恢复原值。

- 脉冲与通信入口输出至仓库根目录的 `GeneratedPure16k/`，目录下保存音频及相关元数据等产物。
- 舰船入口输出至当前工作目录的 `ship_radiated_noise_dataset_toSZ/`，包含各类别 WAV、JSON 和 `manifest.csv`。
- `run_all.sh` 和 `build_pure_pulse_dataset_par.m` 作为原始并行入口保留。本次发布未修改或验证其并行调度行为，运行说明采用串行入口。

## 舰船源模型

源波形由调制连续谱与离散线谱相加得到。当前默认时长为 10–30 秒，五类源各 16,000 条。连续谱采用 300 Hz 平台及高频每倍频程下降 6 dB 的结构，叠加轴频和叶频调制。每条样本包含 3–10 根线谱，部分绑定轴频或叶频谐波，局部线谱与连续谱之比设为 6–10 dB。

源级几何元数据供后续信道处理使用，原始源生成阶段没有对混合波形施加 BELLHOP 传播。

## 本次代码快照

`.m`、`.sh`、已有 `.mat` 和声学 `.env` 输入均从本地源目录原样复制。`SOURCE_SNAPSHOT_SHA256.json` 记录这些文件的哈希。说明文档按当前入口更新，生成输出和临时运行日志不纳入版本管理。

本次上传进行了文件完整性和静态检查，未在当前机器重新执行 MATLAB/Octave 音频生成。
