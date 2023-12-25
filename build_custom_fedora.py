import argparse
import os
import shutil
import subprocess
from pykickstart.parser import KickstartParser


def verify_kickstart(ks_file):
    """
    Verifies the kickstart file using pykickstart.
    """
    parser = KickstartParser()
    try:
        parser.readKickstart(ks_file)
    except Exception as e:
        raise ValueError(f"Invalid kickstart file: {e}")


def mount_iso(iso_path, mount_point):
    """
    Mounts the ISO to a specified mount point.
    """
    if not os.path.isfile(iso_path):
        raise ValueError("ISO file not found.")

    os.makedirs(mount_point, exist_ok=True)
    subprocess.run(["mount", "-o", "loop", iso_path, mount_point], check=True)


def unmount_iso(mount_point):
    """
    Unmounts the ISO.
    """
    subprocess.run(["umount", mount_point], check=True)


def copy_iso_contents(source_dir, target_dir):
    """
    Copies the contents of the mounted ISO to a working directory.
    """
    if not os.path.isdir(source_dir):
        raise ValueError("Source directory does not exist.")
    if not os.path.isdir(target_dir):
        os.makedirs(target_dir)

    for item in os.listdir(source_dir):
        s = os.path.join(source_dir, item)
        d = os.path.join(target_dir, item)
        if os.path.isdir(s):
            shutil.copytree(s, d, symlinks=True)
        else:
            shutil.copy2(s, d)


def modify_isolinux_cfg(isolinux_dir, ks_file):
    """
    Modifies the isolinux.cfg file to include the kickstart file.
    """
    isolinux_cfg_path = os.path.join(isolinux_dir, "isolinux.cfg")
    with open(isolinux_cfg_path, "a") as cfg:
        cfg.write(
            f"\nlabel kickstart\n  menu label ^Install system with kickstart\n  menu default\n  kernel vmlinuz\n  append initrd=initrd.img inst.ks=cdrom:/isolinux/{ks_file} quiet\n"
        )


def create_new_iso(source_dir, output_iso):
    """
    Creates a new ISO image from the modified contents.
    """
    cmd = [
        "genisoimage",
        "-U",
        "-r",
        "-v",
        "-T",
        "-J",
        "-joliet-long",
        '-V "Fedora Custom"',
        "-volset",
        '-A "Fedora Custom"',
        "-b isolinux/isolinux.bin",
        "-c isolinux/boot.cat",
        "-no-emul-boot",
        "-boot-load-size 4",
        "-boot-info-table",
        "-o",
        output_iso,
        source_dir,
    ]

    subprocess.run(" ".join(cmd), shell=True, check=True)


def parse_arguments():
    """
    Parses command-line arguments.
    """
    parser = argparse.ArgumentParser(
        description="Create a custom Fedora ISO with a kickstart file."
    )
    parser.add_argument(
        "-o", "--output", required=True, help="Output directory for the new ISO"
    )
    parser.add_argument(
        "-k", "--kickstart", required=True, help="Path to the kickstart file"
    )
    parser.add_argument(
        "-i", "--input", required=True, help="Path to the input Fedora ISO"
    )
    parser.add_argument(
        "-m", "--mount", required=True, help="Mount point of the input ISO"
    )
    return parser.parse_args()


def main():
    args = parse_arguments()

    try:
        verify_kickstart(args.kickstart)

        mount_iso(args.input, args.mount)
        working_dir = os.path.join(args.output, "working")
        output_iso = os.path.join(args.output, "custom-fedora.iso")

        copy_iso_contents(args.mount, working_dir)

        isolinux_dir = os.path.join(working_dir, "isolinux")
        if not os.path.exists(isolinux_dir):
            os.makedirs(isolinux_dir)
            subprocess.run()

        shutil.copy2(args.kickstart, isolinux_dir)

        modify_isolinux_cfg(isolinux_dir, os.path.basename(args.kickstart))
        create_new_iso(working_dir, output_iso)

        print("Custom Fedora ISO created successfully.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        unmount_iso(args.mount)


if __name__ == "__main__":
    main()
