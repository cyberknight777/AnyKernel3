### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## cyberknight777 @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=DragonHeart for Motorola moto G54 5G by cyberknight777 @ xda-developers
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=cancunf
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

$BOOTMODE || \
abort "[✗] Use userspace kernel flashing applications to flash"

# boot install
split_boot; # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

flash_boot; # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
## end boot install

# vendor_boot shell variables
BLOCK=vendor_boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# reset for vendor_boot patching
reset_ak;

# vendor_boot install
split_boot; # use split_boot to skip ramdisk unpack, e.g. for dtb on devices with hdr v4 but no vendor_kernel_boot

if [ -f $AKHOME/modules/dlkm.cpio.lz4 ]; then
    ui_print " " "- [✓] LZ4 CPIO archive found. Starting vendor_ramdisk modules update..."

    ui_print "- [•] Decompressing the archive..."
    magiskboot decompress $AKHOME/modules/dlkm.cpio.lz4 $AKHOME/dlkm.cpio || \
        abort "[✗] Failed to decompress LZ4 CPIO archive"

    magiskboot cpio $AKHOME/dlkm.cpio test
    cpio_check=$?
    if [ $cpio_check -eq 1 ]; then
        abort "[✗] Decompressed CPIO archive error"
    fi

    ui_print "- [•] Updating vendor_ramdisk modules..."
    mv $AKHOME/dlkm.cpio $SPLITIMG/vendor_ramdisk/dlkm.cpio || \
        abort "[✗] Updating vendor_ramdisk modules failed"

    ui_print "- [✓] Flashing new vendor_ramdisk image..."
fi

flash_boot; # use flash_boot to skip ramdisk repack, e.g. for dtb on devices with hdr v4 but no vendor_kernel_boot
## end vendor_boot install


# reset for vendor_dlkm patching
reset_ak;

## vendor_dlkm install
if [ -f $AKHOME/modules/dlkm.tar.xz ]; then
    ui_print " " "/dev/block/mapper/vendor_dlkm${SLOT}"
    ui_print " " "- [✓] XZ tarball found. Starting /vendor_dlkm modules update..."

    ui_print "- [•] Pulling /vendor_dlkm image from current slot (${SLOT})..."
    dd if=/dev/block/mapper/vendor_dlkm${SLOT} of=${AKHOME}/vendor_dlkm.img || \
        abort "[✗] Failed to pull vendor_dlkm${SLOT}.img"
    extract_vendor_dlkm_dir=${AKHOME}/_extract_vendor_dlkm
    mkdir -p $extract_vendor_dlkm_dir || \
        abort "[✗] Failed to create $extract_vendor_dlkm_dir"

    ui_print "- [•] Unpacking /vendor_dlkm image..."
    ${BIN}/extract.erofs -i ${AKHOME}/vendor_dlkm.img -x -T8 -o ${extract_vendor_dlkm_dir} &> /dev/null || \
        abort "[✗] Failed to unpack the vendor_dlkm image"
    sync

    ui_print "- [•] Updating /vendor_dlkm modules..."
    extract_vendor_dlkm_modules_dir=${extract_vendor_dlkm_dir}/vendor_dlkm/lib/modules
    rm -f ${extract_vendor_dlkm_modules_dir}/* || \
        abort "[✗] Failed to remove pre-existing files in ${extract_vendor_dlkm_modules_dir}"
    rm -f ${extract_vendor_dlkm_dir}/config/vendor_dlkm_{fs_config,file_contexts} || \
        abort "[✗] Failed to remove pre-existing fs_config and file_contexts in ${extract_vendor_dlkm_dir}/config"
    busybox tar -xpf ${AKHOME}/modules/dlkm.tar.xz -C ${extract_vendor_dlkm_dir}/vendor_dlkm/ || \
        abort "[✗] Failed to extract XZ-compressed tarball"
    mv ${AKHOME}/config/vendor_dlkm* ${extract_vendor_dlkm_dir}/config/ || \
        abort "[✗] Failed to move fs_config and file_contexts to ${extract_vendor_dlkm_dir}/config"

    ui_print "- [•] Repacking /vendor_dlkm image..."
    rm -f ${AKHOME}/vendor_dlkm.img || \
        abort "[✗] Failed to remove pre-existing vendor_dlkm.img"
    ${BIN}/mkfs.erofs \
          --mount-point /vendor_dlkm \
          --fs-config-file ${extract_vendor_dlkm_dir}/config/vendor_dlkm_fs_config \
          --file-contexts ${extract_vendor_dlkm_dir}/config/vendor_dlkm_file_contexts \
          -z lz4hc,9 \
          -b 4096 \
          -C 262144 \
          -T 1230768000 \
          ${AKHOME}/vendor_dlkm.img ${extract_vendor_dlkm_dir}/vendor_dlkm || \
        abort "[✗] Failed to repack the vendor_dlkm image"
    rm -rf ${extract_vendor_dlkm_dir} || \
        abort "[✗] Failed to remove working directory"
    unset extract_vendor_dlkm_dir extract_vendor_dlkm_modules_dir

    ui_print "- [✓] Flashing new /vendor_dlkm image..."
    flash_generic vendor_dlkm;
fi
## end vendor_dlkm install
