#!/usr/bin/python3 
import subprocess
import argparse
import re

def run_command(command):
    """
    Execute a shell command and return the output.
    """
    try:
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as e:
        return e.output
    return output

def get_vg_free_space(vg_name):
    """
    Get the free space available in the specified volume group.
    """
    vg_info = run_command(f"vgdisplay {vg_name} | grep 'Free  PE'")
    free_space = re.search(r'\d+\.\d+ GiB', vg_info)
    if free_space:
        return free_space.group()
    else:
        return "0 GiB"

def extend_logical_volume_full(vg_name, lv_name):
    """
    Extend the logical volume to use all available space in the volume group.
    """
    free_space = get_vg_free_space(vg_name)
    extend_command = f"lvextend -l +100%FREE /dev/{vg_name}/{lv_name}"
    extend_output = run_command(extend_command)
    print(extend_output)

    resize_fs_command = "xfs_growfs /"  # Assuming XFS filesystem. Change if different.
    resize_fs_output = run_command(resize_fs_command)
    print(resize_fs_output)

def main():
    parser = argparse.ArgumentParser(description="Expand LVM to Use Full Disk Space")
    parser.add_argument("--vg", type=str, required=True, help="Volume group name")
    parser.add_argument("--lv", type=str, required=True, help="Logical volume name")
    
    args = parser.parse_args()

    extend_logical_volume_full(args.vg, args.lv)

if __name__ == "__main__":
    main()

