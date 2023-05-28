# a badly made guide/ helper script to enable full virtualizaion in proxmox with nvida gpu (maxwell through pascal archetectures)

# advantages over other guides ive found
- Host gpu capabilities in proxmox host, LXC, PVE, and VM simultaneously
- enables video output and desktop environment on proxmox host with vGPU 


## usage

- step naught, uninstall drivers and cuda and reboot (youll need SSH!) commands: `nvidia-uninstall` and `/usr/local/cuda-<version>/bin/cuda-uninstaller`
- step one, clone repo and aquire required files, (look in repo/unpatched/requiredfiles.md5)
- step B, edit the script for the required archetecture and run `./proxmox-fullvirt.sh
- step 9, go through these guides, using the patched drivers instead of the drivers they want you to use, and dont do any patching
- 1) https://gist.github.com/egg82/90164a31db6b71d36fa4f4056bbee2eb
- 2\) https://gitlab.com/polloloco/vgpu-proxmox 
- final step, get ffmpeg with nvenc somehow (jellyfin-ffmpeg will suffice) and test your LXC and VM with (this command)[https://github.com/keylase/nvidia-patch/wiki/Verify-NVENC-patch] 
- -1 before last step, star, donate or whatever if it worked maybe






### ["Give me money. Money me! Money now! Me a money needing a lot now."](https://paypal.me/DvdIsDead)
