#!/bin/bash

set -eu

SCRIPTS_DIR=$(cd `dirname $0`; pwd)
if [ -h $0 ]
then
	CMD=$(readlink $0)
	SCRIPTS_DIR=$(dirname $CMD)
fi
cd $SCRIPTS_DIR
cd ../
TOP_DIR=$(pwd)

TARGET_FRIENDLYWRT_CONFIG=$1
FRIENDLYWRT_SRC_PATHNAME=$2
TARGET_PLAT=$3

## not use:
## rk3328# export SOC_CFLAGS="-march=armv8-a+crypto+crc -mcpu=cortex-a53+crypto+crc -mtune=cortex-a53"
## rk3568# export SOC_CFLAGS="-march=armv8-a+crypto+crc -mcpu=cortex-a55+crypto+crc -mtune=cortex-a55"
## rk3399# export SOC_CFLAGS="-march=armv8-a+crypto+crc -mcpu=cortex-a73.cortex-a53+crypto+crc -mtune=cortex-a73.cortex-a53"

export SOC_CFLAGS="-march=armv8-a+crypto+crc -mcpu=cortex-a53+crypto+crc -mtune=cortex-a53"
cd ${TOP_DIR}/${FRIENDLYWRT_SRC_PATHNAME}
cat >make.sh <<EOF
#!/bin/bash
export SOC_CFLAGS="${SOC_CFLAGS}"
make -j1 V=s
EOF
chmod 755 make.sh

if [ ! -f .config ]; then
	if [ -d ${TOP_DIR}/configs/${TARGET_FRIENDLYWRT_CONFIG} ]; then
		CURRPATH=$PWD
		readonly CURRPATH
		touch ${CURRPATH}/.config
		(cd ${TOP_DIR}/configs/${TARGET_FRIENDLYWRT_CONFIG} && {
			for FILE in $(ls); do
				if [ -f ${FILE} ]; then
					echo "# apply ${FILE} to .config"
					cat ${FILE} >> ${CURRPATH}/.config
				fi
			done
		})
	else
		cp ${TOP_DIR}/configs/${TARGET_FRIENDLYWRT_CONFIG} .config
	fi
	sed -i -e '/^# CONFIG_PACKAGE_kmod-/d' .config
	echo CONFIG_ALL_KMODS=y >> .config
	make defconfig
else
	echo "using .config file"
fi

true ${DEBUG_DOT_CONFIG:=0}
if [ $DEBUG_DOT_CONFIG -eq 1 ]; then
	echo "Abort because DEBUG_DOT_CONFIG=1"
	exit 0
fi

if [ ! -d dl ]; then
	# FORTEST
	# cp -af /opt4/openwrt-full-dl ./dl
	echo "dl directory doesn't  exist. Will make download full package from openwrt site."
fi
make download -j$(nproc)
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;

#make -j$(nproc) V=sc
#RET=$?
#if [ $RET -eq 0 ]; then
#	exit 0
#fi

make -j1 V=sc
RET=$?
if [ $RET -eq 0 ]; then
	exit 0
fi

exit 1
