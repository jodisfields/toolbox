import subprocess
import argparse
import os

def run_command(command):
    """ Utility function to run shell commands """
    try:
        subprocess.check_call(command, shell=True)
    except subprocess.CalledProcessError as e:
        print(f"Error executing {e.cmd}: {e.returncode}")
        raise SystemExit(e)

def main(input_folder, output_image, size="20G"):
    """ Main function to create a qcow2 image from a directory """
    print("Creating QCOW2 image...")
    run_command(f"qemu-img create -f qcow2 {output_image} {size}")
    
    print("Loading nbd module...")
    run_command("modprobe nbd max_part=8")
    
    print("Connecting QCOW2 image as network block device...")
    run_command(f"qemu-nbd --connect=/dev/nbd0 {output_image}")
    
    try:
        print("Formatting the QCOW2 image with ext4...")
        run_command("mkfs.ext4 /dev/nbd0")
        
        print("Mounting the QCOW2 image...")
        mount_point = '/mnt/qcow2'
        os.makedirs(mount_point, exist_ok=True)
        run_command(f"mount /dev/nbd0 {mount_point}")
        
        print("Copying files to the QCOW2 image...")
        run_command(f"cp -a {input_folder}/* {mount_point}/")
        
    finally:
        print("Unmounting and cleaning up...")
        run_command(f"umount {mount_point}")
        run_command("qemu-nbd --disconnect /dev/nbd0")
#        run_command("modprobe -r nbd")
        os.rmdir(mount_point)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Create a QCOW2 image from a directory of ISO contents.')
    parser.add_argument('input_folder', type=str, help='Path to the folder containing the ISO contents')
    parser.add_argument('output_image', type=str, help='Path where the QCOW2 image will be created')
    parser.add_argument('--size', type=str, default='20G', help='Size of the QCOW2 image (default: 20G)')
    
    args = parser.parse_args()
    
    main(args.input_folder, args.output_image, args.size)

