# Alternate Build-Manifest Capability

As of this document's author-date (2020-03-06), the AMIgen7 scripts now support the creation of AMIs with customized build-manifests. Two modes are supported:

- **Groups:** Packages included in the AMI are as maintained in the AMI's source yum repository
- **Manifest-File:** packages included in the AMI are specified in an external, user-authored manifest-file.

## Groups Mode

This mode is considered to be a **"Beta"** feature. It is treated as beta due to inconsistent bility to leverage all of the standard groups defined in EL7 base repositories. As of this writing, it is known to work with the following `yum` groups:

- minimal
- compute-node-environment
- file-print-server-environment
- infrastructure-server-environment
- web-server-environment

It has consistently failed to work with:

- virtualization-host-environment
- graphical-server-environment
- gnome-desktop-environment
- kde-desktop-environment
- developer-workstation-environment

It is invoked by passing the `-g` flag with one of `yum`'s "Environment Groups" as its argument. This is a flagged-argument to the `ChrootBuild.sh` script. When specified, it will look for the named-group in the `yum` repository from which the AMI is being built. To see groups available in the `yum` repository, execute `yum -v grouplist`: use the lower-case group-name values listed in parentheses.

## Manifest-File Mode

This mode makes use of a user-authored package-manifest file. It is expected that the manifest file will contain a list of all RPMs - and associated dependencies - necessary to create a target operating system configuration. Each RPM should be listed on its own line. Selection of this mode will override the default `core` mode as well as any groups selected with the `-g` flagged-option.

This project includes example manifests in the `PkgManifests` directory. These files are strictly examples and should not be considered "fit for use".

It is recommended to create a manifest file by doing an RPM-audit of a reference system. This *should* result in the creation of an equivlent, passing build. 

Note: To pass the final build-validation step, all listed RPMs must be present in the final AMI.
