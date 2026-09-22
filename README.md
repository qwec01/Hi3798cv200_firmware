# DVBIP Firmware

本仓库是 Hi3798Cv200 Debian AArch64 所需的运行时固件和用户态工具

## 一键安装

```sh
wget -O /tmp/install-dvbip-firmware.sh \
  https://raw.githubusercontent.com/DVBIP-Development/DVB-IP/main/DVBIP-Development/firmware/install-dvbip-firmware.sh
sudo bash /tmp/install-dvbip-firmware.sh
```

安装脚本会自动安装 Debian `ffmpeg` 及其依赖，下载并校验本目录中的 `hivxe-ffmpeg-9.0.1`、HiVXE 工具、解码器和 MxL214 固件，安装 OSCam 配置与systemd 服务，并启用 `oscam.service`。

安装后 `/usr/bin/ffmpeg` 和 `/usr/local/bin/hivxe-ffmpeg` 同时存在，互不覆盖。

已有的 `/usr/local/etc/oscam.*` 默认不会覆盖。需要恢复公开模板时使用：

```sh
sudo bash /tmp/install-dvbip-firmware.sh --force-config
```

仓库或分支地址不同时，可通过 `DVBIP_FIRMWARE_BASE_URL` 覆盖下载根地址。

## 文件

| 路径 | 内容 |
| --- | --- |
| `hivxe-ffmpeg-9.0.1` | FFmpeg 9.0.1 的单文件 AArch64 HiVXE 运行时，支持 V4L2 Request、V4L2 M2M 和 CPU 路径 |
| `hivxe-top` | HiVXE、VDEC、编码器和 CPU 状态监视工具 |
| `hisilicon/histb-avsp.bin` | Hi3798CV200 AVS 解码 DSP 微码 |
| `hisilicon/histb-h264-cabac.bin` | Hi3798CV200 H.264 CABAC 微码 |
| `hisilicon/histb-hevc-cabac.bin` | Hi3798CV200 HEVC CABAC 微码 |
| `mxl214/mxl214.fw` | MaxLinear MxL214 DVB-C 前端固件 |
| `mxl214/nvram50.bin` | MaxLinear MxL214 参数/NVRAM 数据 |
| `oscam/oscam` | 静态链接的 AArch64 OSCam 主程序, WebUI端口8888 |
| `oscam/config/oscam.conf` | OSCam 全局和 DVBAPI 模板 |
| `oscam/config/oscam.dvbapi` | 公共 DVBAPI 规则占位模板 |
| `oscam/config/oscam.server` | `ttySCI0` 内置读卡器模板 |
| `oscam/config/oscam.user` | Tvheadend 使用的用户模板 |
| `oscam/config/oscam.service` | OSCam systemd 服务单元 |

这些文件由匹配的 Linux 内核和 rootfs 使用；本目录不提供 `histb-vdec`、MxL214 或其他内核模块。
