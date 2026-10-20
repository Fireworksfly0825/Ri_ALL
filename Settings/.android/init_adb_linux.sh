echo "Init"
UDEV_RULES_NAME="77-android.rules"
# [[ "`which adb`" == : ]] && sudo apt update && sudo apt install -y android-tools-adb
# [[ "`which fastboot`" == "" ]] && sudo apt update && sudo apt install -y android-tools-fastboot
# [[ ! -d ${HOME}/.android ]] && mkdir -p ${HOME}/.andriod
[[ ! -f ${HOME}/.android/adb_usb.ini ]] && echo -e "0xfff0\n0x2ca3" > ${HOME}/.android/adb_usb.ini
if [[ ! -f "/etc/udev/rules.d/${UDEV_RULES_NAME}" ]]; then
    echo -e 'SUBSYSTEM=="usb", ATTRS{idVendor}=="2ca3", ATTRS{idProduct}=="001f", MODE="0666"\nSUBSYSTEM=="usb", MODE=="0666", GROUP="plugdev"' > ${UDEV_RULES_NAME}
    chmod a+x ${UDEV_RULES_NAME}
    sudo mv ${UDEV_RULES_NAME} /etc/udev/rules.d/${UDEV_RULES_NAME}
fi
# sudo usermod -a -G plugdev $(id -u -n)
sudo udevadm control --reload-rules
sudo service udev restart
sudo udevadm trigger
adb kill-server
adb start-server
echo "Init adb success~"
exit 0
