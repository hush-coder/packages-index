RUYI = ruyi_plugin_rev(1)

load(
    "ruyi-plugin://internal-device-provisioner-common",
    _do_dd="do_dd",
    _do_fastboot="do_fastboot",
    _do_fastboot_flash="do_fastboot_flash",
    _pretend_dd="pretend_dd",
    _pretend_fastboot="pretend_fastboot",
    _need_host_blkdevs_all="need_host_blkdevs_all",
    _need_host_blkdevs_none="need_host_blkdevs_none",
)

#
# Implementation
#

#def flash_dd(img_paths: PartitionMapDecl, blkdev_paths: PartitionMapDecl) -> int:
def _flash_dd(img_paths, blkdev_paths):
    for part, img_path in img_paths.items():
        blkdev_path = blkdev_paths[part]
        ret = _do_dd(img_path, blkdev_path)
        if ret != 0:
            return ret

    return 0


#def _pretend_lpi4a_uboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> list[str]:
def _pretend_lpi4a_uboot(img_paths, blkdev_paths):
    p = img_paths["uboot"]
    return [
        "flash [yellow]" + p + "[/] into device RAM",
        "reboot the device",
        "flash [yellow]" + p + "[/] into device partition [green]uboot[/]",
    ]


#def _flash_lpi4a_uboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> int:
def _flash_lpi4a_uboot(img_paths, blkdev_paths):
    # Perform the equivalent of the following commands from the Sipeed Wiki:
    #
    # sudo ./fastboot flash ram ./images/u-boot-with-spl-lpi4a-16g.bin
    # sudo ./fastboot reboot
    # sleep 1
    # sudo ./fastboot flash uboot ./images/u-boot-with-spl-lpi4a-16g.bin
    #
    # See: https://wiki.sipeed.com/hardware/en/lichee/th1520/lpi4a/4_burn_image.html
    uboot_img_path = img_paths["uboot"]

    RUYI.log.I("flashing uboot image into device RAM")
    ret = _do_fastboot("flash", "ram", uboot_img_path)
    if ret != 0:
        RUYI.log.F("failed to flash uboot image into device RAM")
        RUYI.log.W("the device state should be intact, but please re-check")
        return ret

    RUYI.log.I("rebooting device into new uboot")
    ret = _do_fastboot("reboot")
    if ret != 0:
        RUYI.log.F("failed to reboot the device")
        RUYI.log.W("the device state should be intact, but please re-check")
        return ret

    wait_secs = 1.0
    RUYI.log.I("waiting " + str(wait_secs) + "s for the device to come back online")
    RUYI.sleep(wait_secs)

    return _do_fastboot_flash("uboot", uboot_img_path)


#def _flash_fastboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> int:
def _flash_fastboot(img_paths, blkdev_paths):
    for partition, img_path in img_paths.items():
        ret = _do_fastboot_flash(partition, img_path)
        if ret != 0:
            return ret

    return 0

#
# Device Provisioning Strategy Plugin Interface
#

_dd_v1 = {
    "priority": 0,
    "need_host_blkdevs_fn": _need_host_blkdevs_all,
    "need_cmd": ["sudo", "dd"],
    "pretend_fn": _pretend_dd,
    "flash_fn": _flash_dd,
}

_fastboot_v1 = {
    "priority": 0,
    "need_host_blkdevs_fn": _need_host_blkdevs_none,
    "need_cmd": ["sudo", "fastboot"],
    "pretend_fn": _pretend_fastboot,
    "flash_fn": _flash_fastboot,
}

_fastboot_lpi4a_uboot_v1 = {
    "priority": 10,
    "need_host_blkdevs_fn": _need_host_blkdevs_none,
    "need_cmd": ["sudo", "fastboot"],
    "pretend_fn": _pretend_lpi4a_uboot,
    "flash_fn": _flash_lpi4a_uboot,
}

PROVIDED_DEVICE_PROVISION_STRATEGIES_V1 = {
    "dd-v1": _dd_v1,
    "fastboot-v1": _fastboot_v1,
    "fastboot-v1(lpi4a-uboot)": _fastboot_lpi4a_uboot_v1,
}
