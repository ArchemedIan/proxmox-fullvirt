#!/bin/bash

BRANCH=525.85				#driver ver
GFXCARD_device_id=1B80		#use lspci

#vGPU cards ***		GPU Chip	vGPU unlock supported:
#Tesla M10		GM107 x4	Most Maxwell 1.0 cards
#Tesla M60		GM204 x2	Most Maxwell 2.0 cards
#Tesla P40		GP102		Most Pascal cards
#Tesla V100 16GB	GV100		Titan V, Quadro GV100
#Quadro RTX 6000	TU102		Most Turing cards
#### Ampere is not supported ####### Ampere is not supported ####RTX A6000		GA102

######################################################################################
### ***use above table to pick which to uncomment (only one should be uncommented) ###
######################################################################################

#maxwell-1 = Tesla M10
#vdevid=13BD

#maxwell-2 = Tesla M60
#vdevid=13F2

#pascal = Tesla P40
vdevid=1D01

#Titan V, Quadro GV100 = Tesla V100 16GB
#vdevid=1DB4

#turing = Quadro RTX 6000
#vdevid=1E30

if [ -z "$vdevid" ]
then
	echo "!!!!!!!!!!!!!!!!!!!!!!!"
    echo "quadro dev id is not set, exiting."
	exit 1
fi

echo
echo making sure we have dependencies...
sudo apt install osslsigncode mono-devel mscompress >/dev/null

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo
echo downloading patcher
echo
rm -rf patcher-$BRANCH
#git clone --recursive -b $BRANCH https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher.git patcher-$BRANCH 
git clone --recursive -b $BRANCH https://github.com/ArchemedIan/vGPU-Unlock-patcher-docker-test.git patcher-$BRANCH 
echo
echo patching patcher with selected gpu dev id
echo
patcher=$SCRIPT_DIR/patcher-$BRANCH/patch.sh
sed -i "s|0x1B38 0x0 0x1B81 0x0000|0x$vdevid 0x0 0x$GFXCARD_device_id 0x0000|g" "$patcher"
sed -i "s|# GTX 1070|#added with proxmox_fullvirt|g" "$patcher"
#todocheck md5
echo
echo checking unpatched drivers
echo
cd $SCRIPT_DIR/$BRANCH/unpatched || echo " cant find dir with unpatched drivers"
export md5mismatch=0
input="$SCRIPT_DIR/$BRANCH/unpatched/required_files.md5"
while IFS= read -r line
do
	rfile=`echo "$line" |awk  '{print $2}'`
	ls $rfile || export md5mismatch=1 
	md5=`echo "$line" |awk  '{print $1}'`
	echo "--expected md5: $md5"
	md5test=($(md5sum $rfile))
	echo "--calculated md5: $md5test"
	echo
	[[ "$md5" == "$md5test" ]] || export md5mismatch=1
done < "$input" || export md5mismatch=1
[[ "$md5mismatch" == "1" ]] && echo MD5 MISMATCH! EXITING!!
[[ "$md5mismatch" == "1" ]] && exit 3

mkdir -p $SCRIPT_DIR/$BRANCH/patched/host-container 
mkdir $SCRIPT_DIR/$BRANCH/patched/vm 

echo
echo "patching drivers drivers (go get your coffee now)"
echo
# a driver merged from vgpu-kvm with consumer driver (cuda and opengl for host too)
$patcher --repack general-merge || exit 1
name=NVIDIA-Linux-*-merged-vgpu-kvm
mv ${name}-patched.run $SCRIPT_DIR/$BRANCH/patched/host-container/
mv ${name}-patched $SCRIPT_DIR/$BRANCH/patched/host-container/
rm -rf ${name}
sync

# display output on host not needed (proxmox) or you have secondary gpu
#$patcher --repack vgpu-kvm || exit 1
#name=NVIDIA-Linux-*-vgpu-kvm
#mv ${name}-patched.run $SCRIPT_DIR/$BRANCH/patched/host/
#mv ${name}-patched $SCRIPT_DIR/$BRANCH/patched/host/
#rm -rf ${name}
#sync

# driver for linux vm
$patcher --repack grid || exit 1
name=NVIDIA-Linux-*-grid
mv ${name}-patched.run $SCRIPT_DIR/$BRANCH/patched/vm/
mv ${name}-patched $SCRIPT_DIR/$BRANCH/patched/vm/
rm -rf ${name}
sync

# driver for linux vm functionally similar to grid one but using consumer .run as input
$patcher --repack general || exit 1
name=NVIDIA-Linux-*
mv ${name}-patched.run $SCRIPT_DIR/$BRANCH/patched/vm/
mv ${name}-patched $SCRIPT_DIR/$BRANCH/patched/vm/
rm -rf ${name}/
sync

# stuff for windows vm
$patcher --create-cert wsys || exit 1
$patcher --repack wsys || exit 1
name=NVIDIA-Windows-*
#mv ${name}-patched.exe $SCRIPT_DIR/$BRANCH/patched/vm/
mv ${name}-patched $SCRIPT_DIR/$BRANCH/patched/vm/
#rm -rf ${name}/
sync
mkdir $SCRIPT_DIR/$BRANCH/tmp

echo
echo ------------------------------------------------------------
echo
echo "Line to install driver in proxmox host: "
echo "-- $(ls $SCRIPT_DIR/$BRANCH/patched/host-container/NVIDIA-Linux-*-merged-vgpu-kvm-patched.run) --no-x-check -zZ --dkms"
echo
echo "Line to install driver in Linux Container (consumer driver):"
echo "-- $(ls $SCRIPT_DIR/$BRANCH/patched/host-container/NVIDIA-Linux-*-merged-vgpu-kvm-patched.run) -asqzZ --no-kernel-modules --no-x-check --tmpdir=$SCRIPT_DIR/$BRANCH/tmp"
echo "--- using the temp dir saves space in your container, "
echo "--- this also assumes youre passing $SCRIPT_DIR to your container via proxmox mountpoint)"
echo
echo "Install driver in Linux vm normally,"
echo "-- for the Grid driver use: $(ls $SCRIPT_DIR/$BRANCH/patched/container-vm/NVIDIA-Linux-*-grid-patched.run)"
echo "-- for the consumer driver use: $(ls $SCRIPT_DIR/$BRANCH/patched/vm/NVIDIA-Linux-*-patched.run| grep -v grid)"
echo
echo Install cuda toolkit for ffmpeg/nvenc/docker
echo -- cuda_12.0.0_525.60.13_linux.run --toolkit --silent --tmpdir=$SCRIPT_DIR/$BRANCH/tmp
exit 0


