# 自动构建斐讯 N1 OpenWrt 固件脚本
# Automatically Build OpenWrt Firmware for PHICOMM N1

**制作脚本已部署到 Github Action，真正实现一栈式全自动构建，每周六早上六点准时为你构建，无须自行制作，下载即可用**

[![N1-OpenWrt-CI](https://github.com/tuanqing/mknop/workflows/N1-OpenWrt-CI/badge.svg?branch=master)](https://github.com/tuanqing/mknop/actions)  
 👆👆👆&nbsp; &nbsp; 戳上面查看构建状态

## 使用方法

1. Linux环境，推荐使用 Ubuntu 18.04 LTS
2. 编译好待构建的 OpenWrt 固件，不会的自行科普 [Lean's OpenWrt source](https://github.com/coolsnowwolf/lede "Lean's OpenWrt source")  
   编译N1固件的配置如下：
   ``` 
   Target System (QEMU ARM Virtual Machine)  --->
   Subtarget (ARMv8 multiplatform)  --->
   Target Profile (Default)  --->
   ```

   **注意：  
   一键安装到 emmc 脚本已迁移至 openwrt package，解决需要自选依赖的问题。使用方法如下，悉知！！**

   **用法**：  
   1、`git clone https://github.com/tuanqing/install-program package/install-program`  
   2、执行 `make menuconfig` ，选中 Utilities 下的 install-program
      ``` 
      Utilities  --->  
         <*> install-program
      ```
   3、编译完成之后使用本源码制作镜像写入U盘启动，之后执行 `n1-install` 即可安装到 emmc  
   4、将固件上传到 `/tmp/upgrade`( xxx.img )，之后执行 `n1-update` 即可从该固件升级

3. 克隆仓库到本地  
   `git clone https://github.com/tuanqing/mknop` 
4. 将你编译好的固件拷贝到 openwrt 目录( 可以复制多个固件 )
5. 使用 sudo 执行脚本  
   `sudo ./make` 
6. 按照提示操作，如，选择你要制作的固件、选择内核版本、设置 ROOTFS 分区大小等  
   如果你不了解这些设置项，请直接回车即可，或者直接执行  
   `sudo ./make -d` 
7. 等待构建完成，默认输出文件夹为 out
8. 写盘启动，写盘工具推荐 [Etcher](https://www.balena.io/etcher/)

**注意**：  
1、待构建的固件格式只支持 rootfs.tar[.gz]、 ext4-factory.img[.gz]、root.ext4[.gz] 6种，推荐使用rootfs.tar.gz 格式  
2、默认不会清理 out 目录，请手动删除，或使用 `sudo ./make -c` 清理

## 特别说明

* 目录说明
``` 
   ├── armbian                               armbian 相关文件
   │   └── phicomm-n1                        设备文件夹
   │       ├── boot-common.tar.gz            公有启动文件
   │       ├── firmware.tar.gz               armbian 固件
   │       ├── kernel                        内核文件夹，在它下面添加你的自定义内核
   │       │   └── 5.4.60                    kernel 5.4.60-flippy-42+o @flippy
   │       └── root                          rootfs 文件夹，在它下面添加你的自定义文件
   ├── LICENSE                               license
   ├── make                                  构建脚本
   ├── openwrt                               固件文件夹(to build)
   ├── out                                   固件文件夹(build ok)
   ├── tmp                                   临时文件夹
   └── README.md                             readme, current file
```

* 使用参数
   * `-c, --clean` ，清理临时文件和输出目录
   * `-d, --default` ，使用默认配置来构建固件( openwrt 下的第一个固件、构建所有内核、ROOTFS 分区大小为 512M )
   * `--kernel` ，显示 kernel 文件夹下的所有内核
   * `-k=VERSION` ，设置内核版本，设置为 `all` 将会构架所有内核版本固件，设置为 `latest` 将构建最新内核版本固件
   * `-s, --size=SIZE` ，设置 ROOTFS 分区大小，不要小于 256M
   * `-h, --help` ，显示帮助信息
   * examples：  
      `sudo ./make -c` ，清理文件  
      `sudo ./make -d` ，使用默认配置  
      `sudo ./make -k 5.4.60` ，将内核版本设置为 5.4.60  
      `sudo ./make -k latest` ，使用最新内核  
      `sudo ./make -s 512` ，将 ROOTFS 分区大小设置为 512M  
      `sudo ./make -d -s 512` ，使用默认，并将分区大小设置为 512M  
      `sudo ./make -d -s 512 -k 5.4.60` ，使用默认，并将分区大小设置为 512M，内核版本设置为 5.4.60

* 自定义
   * 使用自定义内核  
     参照内核文件夹( `armbian/phicomm-n1/kernel/xxx` )下的文件提取 kernel.tar.xz、modules.tar.xz

   * 添加自定义文件  
      向 armbian/phicomm-n1/root 目录添加你的文件

      **注意**：添加的文件应保持与 ROOTFS 分区目录结构一致
