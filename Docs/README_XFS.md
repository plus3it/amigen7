# XFS Capability

As of this date, the AMIgen7 scripts now support the creation of AMIs with XFS filesystems.

## Usage

The _default behavior_ for AMIgen7 remains creating EXT4-based AMIs. This ensures that any downstream projects that rely on &ndash; or even merely "expect" &ndash; the prior, EXT4-based behavior, will continue to function without further modification. For those wishing to create AMIs with XFS-based filesystems, it will be necessary to:

# Invoke the `DiskSetup.sh` script with the additional filesystem flag and specify the `xfs` filesystem-type. In other words, add `-f xfs` to whatever method you use to invoke the `DiskSetup.sh` script.
# Invoke the `MkChrootTree.sh` script with the additional script-argument, `<FSTYPE>`. Doing so allows the explicit selection of `ext4` as well as `ext3` (not tested)` or `xfs`. In other words, when calling the `MkChrootTree.sh` script, do so as any of:
* `MkChrootTree.sh <BLOCKDEV>`
* `MkChrootTree.sh <BLOCKDEV> ext4`
* `MkChrootTree.sh <BLOCKDEV> ext3`
* `MkChrootTree.sh <BLOCKDEV> xfs`

In either case, the requested filesystem-type is case sensitive. The scripts will fail if you specify `EXT4`, `EXT3` or `XFS` instead of `ext4`, `ext3` or `xfs` (respectively).
