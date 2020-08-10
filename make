#!/bin/bash

tmp="./tmp"
out="./out"
device="phicomm-n1" # don't modify it
image_name='$device-v$kernel-openwrt-firmware'

tag() {
    echo -e " [ \033[1;36m$1\033[0m ]"
}

process() {
    echo -e " [ \033[1;32m$kernel\033[0m ] $1"
}

die() {
    error "$1" && exit 1
}

error() {
    echo -e " [ \033[1;31mError\033[0m ] $1"
}

loop_setup() {
    loop=$(losetup -P -f --show "$1")
    [ $loop ] || die "you used a lower version Linux, 
 please update the util-linux package or upgrade your system."
}

cleanup() {
    for x in $(grep $(pwd) /proc/mounts | grep -oE "loop[0-9]{1,2}" | sort | uniq); do
        umount -f /dev/${x}p[1-2] 2>/dev/null
        losetup -d "/dev/$x" 2>/dev/null
    done
    rm -rf $tmp
}

extract_openwrt() {
    local firmware="./openwrt/$firmware"
    local suffix="${firmware##*.}"
    mount="$tmp/mount"
    root_comm="$tmp/root_comm"

    mkdir -p $mount $root_comm
    while true; do
        case "$suffix" in
        tar)
            tar -xf $firmware -C $root_comm
            break
            ;;
        gz)
            if ls $firmware | grep -q ".tar.gz$"; then
                tar -xzf $firmware -C $root_comm
                break
            else
                tmp_firmware="$tmp/${firmware##*/}"
                tmp_firmware=${tmp_firmware%.*}
                gzip -d $firmware -c > $tmp_firmware
                firmware=$tmp_firmware
                suffix=${firmware##*.}
            fi
            ;;
        img)
            loop_setup $firmware
            if ! mount -r ${loop}p2 $mount; then
                if ! mount -r ${loop}p1 $mount; then
                    die "mount ${loop} failed!"
                fi
            fi
            cp -r $mount/* $root_comm && sync
            umount -f $mount
            losetup -d $loop
            break
            ;;
        ext4)
            if ! mount -r -o loop $firmware $mount; then
                die "mount $firmware failed!"
            fi
            cp -r $mount/* $root_comm && sync
            umount -f $mount
            break
            ;;
        *)
            die "unsupported firmware format, this script only supports 
 rootfs.tar[.gz], ext4-factory.img[.gz], root.ext4[.gz] six formats."
            ;;
        esac
    done

    rm -rf $root_comm/lib/modules/*/
}

extract_armbian() {
    kernel_dir="./armbian/$device/kernel/$kernel"
    root_dir="./armbian/$device/root"
    root="$tmp/$kernel/root"
    boot="$tmp/$kernel/boot"

    mkdir -p $root $boot

    tar -xJf "./armbian/boot-common.tar.xz" -C $boot
    tar -xJf "$kernel_dir/kernel.tar.xz" -C $boot
    tar -xJf "./armbian/firmware.tar.xz" -C $root
    tar -xJf "$kernel_dir/modules.tar.xz" -C $root

    cp -r $root_comm/* $root
    [ $(ls $root_dir | wc -w) != 0 ] && cp -r $root_dir/* $root
    sync
}

utils() {
    (
        cd $root
        # add other operations below

        echo 'pwm_meson' > etc/modules.d/pwm-meson
        if ! grep -q 'ulimit -n' etc/init.d/boot; then
            sed -i '/kmodloader/i \\tulimit -n 51200\n' etc/init.d/boot
        fi
        if ! grep -q '/tmp/upgrade' etc/init.d/boot; then
            sed -i '/mkdir -p \/tmp\/.uci/a \\tmkdir -p \/tmp\/upgrade' etc/init.d/boot
        fi
        sed -i 's/ttyAMA0/ttyAML0/' etc/inittab
        sed -i 's/ttyS0/tty0/' etc/inittab

        mkdir -p boot run opt
        chown -R 0:0 ./
    )
}

make_image() {
    image="$out/$kernel/$(date "+%y.%m.%d-%H%M%S")-$(eval "echo $image_name").img"

    [ -d "$out/$kernel" ] || mkdir -p "$out/$kernel"
    fallocate -l $((16 + 128 + rootsize))M $image
}

format_image() {
    parted -s $image mklabel msdos
    parted -s $image mkpart primary ext4 17M 151M
    parted -s $image mkpart primary ext4 151M 100%

    loop_setup $image
    mkfs.vfat -n "BOOT" ${loop}p1 >/dev/null 2>&1
    mke2fs -F -q -t ext4 -L "ROOTFS" -m 0 ${loop}p2 >/dev/null 2>&1
}

copy2image() {
    set -e

    local bootfs="$mount/$kernel/bootfs"
    local rootfs="$mount/$kernel/rootfs"

    mkdir -p $bootfs $rootfs
    if ! mount ${loop}p1 $bootfs; then
        die "mount ${loop}p1 failed!"
    fi
    if ! mount ${loop}p2 $rootfs; then
        die "mount ${loop}p2 failed!"
    fi

    cp -r $boot/* $bootfs
    cp -r $root/* $rootfs
    sync

    umount -f $bootfs $rootfs
    losetup -d $loop
}

get_firmwares() {
    firmwares=()
    i=0
    IFS=$'\n'

    [ -d "./openwrt" ] && {
        for x in $(ls ./openwrt); do
            firmwares[i++]=$x
        done
    }
}

get_kernels() {
    kernels=()
    i=0
    IFS=$'\n'

    local kernel_root="./armbian/$device/kernel"
    [ -d $kernel_root ] && {
        work=$(pwd)
        cd $kernel_root
        for x in $(ls ./); do
            [[ -f "$x/kernel.tar.xz" && -f "$x/modules.tar.xz" ]] && kernels[i++]=$x
        done
        cd $work
    }
}

show_kernels() {
    if [ ${#kernels[*]} = 0 ]; then
        die "no file in kernel directory!"
    else
        show_list "${kernels[*]}" "kernel"
    fi
}

show_list() {
    echo " $2: "
    i=0
    for x in $1; do
        echo " ($((++i))) $x"
    done
}

choose_firmware() {
    show_list "${firmwares[*]}" "firmware"
    choose_files ${#firmwares[*]} "firmware"
    firmware=${firmwares[opt]}
    tag $firmware && echo
}

choose_kernel() {
    show_kernels
    choose_files ${#kernels[*]} "kernel"
    kernel=${kernels[opt]}
    tag $kernel && echo
}

choose_files() {
    local len=$1

    if [ "$len" = 1 ]; then
        opt=0
    else
        i=0
        while true; do
            echo && read -p " select $2 above, and press Enter to select the first one: " opt
            [ $opt ] || opt=1
            if [[ "$opt" -ge 1 && "$opt" -le "$len" ]]; then
                let opt--
                break
            else
                ((i++ >= 2)) && exit 1
                error "wrong type, try again!"
                sleep 1s
            fi
        done
    fi
}

set_rootsize() {
    i=0
    rootsize=

    while true; do
        read -p " input the rootfs partition size, defaults to 512m, do not less than 256m
 if you don't know what this means, press Enter to keep default: " rootsize
        [ $rootsize ] || rootsize=512
        if [[ "$rootsize" -ge 256 ]]; then
            tag $rootsize && echo
            break
        else
            ((i++ >= 2)) && exit 1
            error "wrong type, try again!\n"
            sleep 1s
        fi
    done
}

usage() {
    cat <<EOF
Usage:
  make [option]

Options:
  -c, --clean       clean up the output and temporary directories

  -d, --default     use the default configuration, which means that use the first firmware in the "openwrt" directory, \
the kernel version is "all", and the rootfs partition size is 512m

  -k=VERSION        set the kernel version, which must be in the "kernel" directory
     , -k all       build all the kernel version
     , -k latest    build the latest kernel version

  --kernel          show all kernel version in "kernel" directory

  -s, --size=SIZE   set the rootfs partition size, do not less than 256m

  -h, --help        display this help

EOF
}

##
[ $(id -u) = 0 ] || die "please run this script as root!"
echo -e " Welcome to phicomm-n1 openwrt image tools!\n"

cleanup
get_firmwares
get_kernels

while [ "$1" ]; do
    case "$1" in
    -h | --help)
        usage && exit
        ;;
    -c | --clean)
        cleanup
        rm -rf $out
        echo " clean up ok!" && exit
        ;;
    -d | --default)
        : ${rootsize:=512}
        : ${firmware:="${firmwares[0]}"}
        : ${kernel:="all"}
        ;;
    -k)
        kernel=$2
        kernel_dir="./armbian/$device/kernel/$kernel"
        if [[ "$kernel" = "all" || -f "$kernel_dir/kernel.tar.xz" ]]; then
            shift
        elif [ "$kernel" = "latest" ]; then
            kernel="${kernels[-1]}"
            shift
        else
            die "invalid kernel [ $2 ]!!"
        fi
        ;;
    --kernel)
        show_kernels && exit
        ;;
    -s | --size)
        rootsize=$2
        if [[ "$rootsize" -ge 256 ]]; then
            shift
        else
            die "invalid size [ $2 ]!!"
        fi
        ;;
    *)
        die "invalid option [ $1 ]!!"
        ;;
    esac
    shift
done

if [ ${#firmwares[*]} = 0 ]; then
    die "no file in openwrt directory!"
fi
if [ ${#kernels[*]} = 0 ]; then
    die "no file in kernel directory!"
fi

[ $firmware ] && echo " firmware   ==>   $firmware"
[ $kernel ] && echo " kernel     ==>   $kernel"
[ $rootsize ] && echo " rootsize   ==>   $rootsize"
[ $firmware ] || [ $kernel ] || [ $rootsize ] && echo

[ $firmware ] || choose_firmware
[ $kernel ] || choose_kernel
[ $rootsize ] || set_rootsize

[ $kernel != "all" ] && kernels=("$kernel")

process "extract openwrt files "
extract_openwrt

for x in ${kernels[*]}; do
    {
        kernel=$x
        process "extract armbian files "
        extract_armbian
        utils
        process "make openwrt image "
        make_image
        process "format openwrt image "
        format_image
        process "copy files to image "
        copy2image
        process "generate success 😘"
    } &
done

wait

cleanup
chmod -R 777 $out
