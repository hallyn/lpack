set -e

# Default to everything under cwd
# Basedir is where we keep a few things like the mounted tag and a tmpdir "WORKSPACE"
# where we stage new directories to tar up.
basedir="$(pwd)"
# layoutdir is the OCI layout directory
layoutdir="${basedir}/oci"
# lofile is the btrfs loopback file
lofile=
# btrfsmount is where the btrfs filesystem is mounted.
btrfsmount="${basedir}/btrfs"
# vg is the LVM vg to use
vg="stacker"
# lvbasedir is the directory under which LVM LVs will be mounted
lvbasedir="${basedir}/lvm"
# I don't want to keep state, so you can specify the loopback dev
# to use for lvm here, but it must be free for our use.
lvdev="nbd0"
lvsize="20G"
thinsize="15G"
driver="vfs"

parse_config() {
    x="$(mktemp)"
    sed -e 's/:[ \t]*/="/;s/$/"/' "$1" > "${x}"
    . "${x}"
    rm -- "${x}"
}

# Parse config
# Example config to place the OCI layout and loopback file in /tmp, but keep
# mounted btrfs under $cwd:
# cat > atom_config.yaml << EOF
# layoutdir: /tmp/myimage
# lofile: /tmp/lofile
# EOF
# NOTE - changing this between a setup_btrfs and unsetup_btrfs may lead to
# annoying-to-fix leftovers.  Recommend not doing so.

if [ -f ./atom_config.yaml ]; then
    parse_config ./atom_config.yaml
elif [ -f ~/.config/atom/config.yaml ]; then
    parse_config ~/.config/atom/config.yaml
fi

if [ ! -d "${basedir}" ]; then
	echo "basedir does not exist: ${basedir}"
	exit 1
fi

if [ -z "$lofile" ]; then
	if [ "${driver}" = "lvm" ]; then
		lofile="lvm.img"
	else
		lofile = "btrfs.img"
	fi
fi

id_check() {
        if [ $(id -u) != 0 ]; then
                echo "be root"
                exit 1
        fi
}

gettag() {
    res=`umoci stat --image ${layoutdir}:$1 | grep "^sha256:" |  tail -1`
    echo "${res}" | grep -q "^sha256:" || { echo "Bad tag"; exit 1; }
    echo "${res}" | cut -c 8-71
}
