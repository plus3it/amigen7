#!/bin/bash
set -eu -o pipefail
#
# Install, configure and activate AWS utilities
#
#######################################################################
PROGNAME=$(basename "$0")
CHROOTMNT="${CHROOT:-/mnt/ec2-root}"
CLIV1SOURCE="${CLIV1SOURCE:-UNDEF}"
CLIV2SOURCE="${CLIV2SOURCE:-UNDEF}"
ICONNECTSRC="${ICONNECTSRC:-UNDEF}"
DEBUG="${DEBUG:-UNDEF}"
SSMAGENT="${SSMAGENT:-UNDEF}"
UTILSDIR="${UTILSDIR:-UNDEF}"

SYSTEMDSVCS=(
    autotune.service
    amazon-ssm-agent.service
    hibinit-agent.service
    ec2-instance-connect.service
)

# Make interactive-execution more-verbose unless explicitly told not to
if [[ $( tty -s ) -eq 0 ]] && [[ ${DEBUG} == "UNDEF" ]]
then
   DEBUG="true"
fi


# Error handler function
function err_exit {
   local ERRSTR
   local ISNUM
   local SCRIPTEXIT

   ERRSTR="${1}"
   ISNUM='^[0-9]+$'
   SCRIPTEXIT="${2:-1}"

   if [[ ${DEBUG} == true ]]
   then
      # Our output channels
      logger -i -t "${PROGNAME}" -p kern.crit -s -- "${ERRSTR}"
   else
      logger -i -t "${PROGNAME}" -p kern.crit -- "${ERRSTR}"
   fi

   # Only exit if requested exit is numerical
   if [[ ${SCRIPTEXIT} =~ ${ISNUM} ]]
   then
      exit "${SCRIPTEXIT}"
   fi
}

# Print out a basic usage message
function UsageMsg {
   local SCRIPTEXIT
   SCRIPTEXIT="${1:-1}"

   (
      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf '\t%-4s%s\n' '-C' 'Where to get AWS CLIv1 (Installs to /usr/local/bin/aws1)'
      printf '\t%-4s%s\n' '-c' 'Where to get AWS CLIv2 (Installs to /usr/local/bin/aws2)'
      printf '\t%-4s%s\n' '-d' 'Directory containing installable utility-RPMs'
      printf '\t%-4s%s\n' '-h' 'Print this message'
      printf '\t%-4s%s\n' '-i' 'Where to get AWS InstanceConnect (RPM or git URL)'
      printf '\t%-4s%s\n' '-m' 'Where chroot-dev is mounted (default: "/mnt/ec2-root")'
      printf '\t%-4s%s\n' '-s' 'Where to get AWS SSM Agent (Installs via RPM)'
      echo "  GNU long options:"
      printf '\t%-20s%s\n' '--cli-v1' 'See "-C" short-option'
      printf '\t%-20s%s\n' '--cli-v2' 'See "-c" short-option'
      printf '\t%-20s%s\n' '--help' 'See "-h" short-option'
      printf '\t%-20s%s\n' '--instance-connect' 'See "-i" short-option'
      printf '\t%-20s%s\n' '--mountpoint' 'See "-m" short-option'
      printf '\t%-20s%s\n' '--utils-dir' 'See "-d" short-option'
      printf '\t%-20s%s\n' '--ssm-agent' 'See "-s" short-option'
   )
   exit "${SCRIPTEXIT}"
}

# Make sure Python3 is present when needed
function EnsurePy3 {
   # Install python as necessary
   if [[ -x ${CHROOTMNT}/bin/python3 ]]
   then
      err_exit "Python dependency met" NONE
   else
      err_exit "Installing python3..." NONE
      yum --installroot="${CHROOTMNT}" install --quiet -y python3 || \
        err_exit "Failed installing python3"

      err_exit "Creating /bin/python link..." NONE
      chroot "${CHROOTMNT}" bash -c "(
            alternatives --set python /usr/bin/python3
         )" || \
        err_exit "Failed creating /bin/python link"
   fi
}

# Make sure the amzn linux packages are present
function check_amzn_rpms()
{
   mapfile -t AMZNRPMS < <( stat -c '%n' "${UTILSDIR}"/*.el7.*.rpm )
   if [[ ${#AMZNRPMS[@]} -eq 0 ]]
   then
      (
      echo "AMZN.Linux packages not found in ${UTILSDIR}"
      echo "Please download missing RPMs before proceeding."
      echo "Note: GetAmznLx.sh may be used to do this for you."
      echo "Aborting..."
      ) > /dev/stderr
      exit 1
   fi
}

# Enable the RHEL "optional" repo where appropriate
function enable_rhel_optional_repo()
{
    OPTIONREPO=$(yum repolist all | grep rhel-server-optional || true)
    if [[ -n ${OPTIONREPO} ]]
    then
        chroot "${CHROOTMNT}" yum-config-manager --enable "${OPTIONREPO/\/*/}"
    fi
}

# Force systemd services to be enabled in resultant AMI
function enable_services()
{
    for SVC in "${SYSTEMDSVCS[@]}"
    do
        printf "Attempting to enable %s in %s... " "${SVC}" "${CHROOTMNT}"
        chroot "${CHROOTMNT}" /usr/bin/systemctl enable "${SVC}" || err_exit "FAILED"
        echo "SUCCESS"
    done
}

# Get list of rpm filenames
function get_awstools_filenames()
{
    if [[ -z ${AWSTOOLSRPM:-} ]]
    then
        ls "${UTILSDIR}"/*.el7.*.rpm
    else
        rpmfiles=""
        for rpmfile in ${AWSTOOLSRPM}
        do
            rpmfiles="${rpmfiles} "$(ls "${UTILSDIR}/${rpmfile}"*.el7.*.rpm)
        done
        echo "${rpmfiles}"
    fi
}

# Install aws utils rpms
function install_aws_utils()
{
    # Depending on RPMs dependencies, this may fail if a repo is
    # missing (e.g. EPEL). Will also fail if no RPMs are present
    # in the search directory.
    # use yum info .. to check and show details for installed RPMs.
    rpmfiles=$(get_awstools_filenames)
    if [[ -z ${rpmfiles} ]]
    then
        echo "No Installation of additional Amazon RPMs"
    else
        # shellcheck disable=2086
        yum --installroot="${CHROOTMNT}" install -e 0 -y ${rpmfiles} || exit $?
        enable_services
    fi
}

# Install AWS CLI version 1.x
function InstallCLIv1 {
   local INSTALLDIR
   local BINDIR

   INSTALLDIR="/usr/local/aws-cli/v1"
   BINDIR="/usr/local/bin"

   if [[ ${CLIV1SOURCE} == "UNDEF" ]]
   then
      err_exit "AWS CLI v1 not requested for install. Skipping..." NONE
   elif [[ ${CLIV1SOURCE} == http[s]://*zip ]]
   then
      # Make sure Python3 is present
      EnsurePy3

      err_exit "Fetching ${CLIV1SOURCE}..." NONE
      curl -sL "${CLIV1SOURCE}" -o "${CHROOTMNT}/tmp/awscli-bundle.zip" || \
        err_exit "Failed fetching ${CLIV1SOURCE}"

      err_exit "Dearchiving awscli-bundle.zip..." NONE
      (
         cd "${CHROOTMNT}/tmp"
         unzip -q awscli-bundle.zip
      ) || \
        err_exit "Failed dearchiving awscli-bundle.zip"

      err_exit "Installing AWS CLIv1..." NONE
      chroot "${CHROOTMNT}" /bin/bash -c "/tmp/awscli-bundle/install -i '${INSTALLDIR}' -b '${BINDIR}/aws'" || \
         err_exit "Failed installing AWS CLIv1"

      err_exit "Creating AWS CLIv1 symlink ${BINDIR}/aws1..." NONE
      chroot "${CHROOTMNT}" ln -sf "${INSTALLDIR}/bin/aws" "${BINDIR}/aws1" || \
        err_exit "Failed creating ${BINDIR}/aws1"

      err_exit "Cleaning up install files..." NONE
      rm -rf "${CHROOTMNT}/tmp/awscli-bundle.zip" \
         "${CHROOTMNT}/tmp/awscli-bundle" || \
        err_exit "Failed cleaning up install files"
   elif [[ ${CLIV1SOURCE} == pip,* ]]
   then
      # Make sure Python3 is present
      EnsurePy3

      chroot "${CHROOTMNT}" /usr/bin/pip3 install --upgrade "${CLIV1SOURCE/pip*,}"
   fi

}

# Install AWS CLI version 2.x
function InstallCLIv2 {
   local INSTALLDIR
   local BINDIR

   INSTALLDIR="/usr/local/aws-cli"  # installer appends v2/current
   BINDIR="/usr/local/bin"

   if [[ ${CLIV2SOURCE} == "UNDEF" ]]
   then
      err_exit "AWS CLI v2 not requested for install. Skipping..." NONE
   elif [[ ${CLIV2SOURCE} == http[s]://*zip ]]
   then
      err_exit "Fetching ${CLIV2SOURCE}..." NONE
      curl -sL "${CLIV2SOURCE}" -o "${CHROOTMNT}/tmp/awscli-exe.zip" || \
        err_exit "Failed fetching ${CLIV2SOURCE}"

      err_exit "Dearchiving awscli-exe.zip..." NONE
      (
         cd "${CHROOTMNT}/tmp"
         unzip -q awscli-exe.zip
      ) || \
        err_exit "Failed dearchiving awscli-exe.zip"

      err_exit "Installing AWS CLIv2..." NONE
      chroot "${CHROOTMNT}" /bin/bash -c "/tmp/aws/install -i '${INSTALLDIR}' -b '${BINDIR}'" || \
         err_exit "Failed installing AWS CLIv2"

      err_exit "Creating AWS CLIv2 symlink ${BINDIR}/aws2..." NONE
      chroot "${CHROOTMNT}" ln -sf "${INSTALLDIR}/v2/current/bin/aws" "${BINDIR}/aws2" || \
        err_exit "Failed creating ${BINDIR}/aws2"

      err_exit "Cleaning up install files..." NONE
      rm -rf "${CHROOTMNT}/tmp/awscli-exe.zip" \
         "${CHROOTMNT}/tmp/aws" || \
        err_exit "Failed cleaning up install files"
   fi

}

# Install AWS utils from "directory"
function InstallFromDir {
    check_amzn_rpms
    enable_rhel_optional_repo
    install_aws_utils
}

# Install AWS InstanceConnect
function InstallInstanceConnect {
   local BUILD_DIR
   local ICRPM
   local SELPOL

   BUILD_DIR="/tmp/aws-ec2-instance-connect-config"
   SELPOL="ec2-instance-connect"

   if [[ ${ICONNECTSRC} == "UNDEF" ]]
   then
      err_exit "AWS Instance-Connect not requested for install. Skipping..." NONE
      return 0
   elif [[ ${ICONNECTSRC} == *.rpm ]]
   then
      err_exit "Installing v${ICONNECTSRC} via yum..." NONE
      yum --installroot="${CHROOTMNT}" --quiet install -y "${ICONNECTSRC}" || \
        err_exit "Failed installing v${ICONNECTSRC}"
   elif [[ ${ICONNECTSRC} == *.git ]]
   then
      err_exit "Installing InstanceConnect from Git" NONE

      # Build the RPM
      if [[ $( command -v make )$? -ne 0 ]]
      then
         err_exit "No make-utility found in PATH"
      fi

      # Fetch via git
      err_exit "Fetching ${ICONNECTSRC}..." NONE
      git clone "${ICONNECTSRC}" "${BUILD_DIR}" || \
        err_exit "Failed fetching ${ICONNECTSRC}"

      err_exit "Making InstanceConnect RPM..." NONE
      ( cd "${BUILD_DIR}" && make rpm ) || \
        err_exit "Failed to make InstanceConnect RPM"

      # Install the RPM
      ICRPM="$( stat -c '%n' "${BUILD_DIR}"/*noarch.rpm 2> /dev/null )"
      if [[ -n ${ICRPM} ]]
      then
          err_exit "Installing ${ICRPM}..." NONE
          yum --installroot="${CHROOTMNT}" install -y "${ICRPM}" || \
            err_exit "Failed installing ${ICRPM}"
      else
          err_exit "Unable to find RPM in ${BUILD_DIR}"
      fi

   fi

   # Ensure service is enabled
   if [[ $( chroot "${CHROOTMNT}" bash -c "(
               systemctl cat ec2-instance-connect > /dev/null 2>&1
            )" )$? -eq 0 ]]
   then
      err_exit "Enabling ec2-instance-connect service..." NONE
      chroot "${CHROOTMNT}" systemctl enable ec2-instance-connect || \
        err_exit "Failed enabling ec2-instance-connect service"
   else
      err_exit "Could not find ec2-instance-connect in ${CHROOTMNT}"
   fi

   # Ensure SELinux is properly configured
   #   Necessary pending resolution of:
   #   - https://github.com/aws/aws-ec2-instance-connect-config/issues/2
   #   - https://github.com/aws/aws-ec2-instance-connect-config/issues/19
   err_exit "Creating SELinux policy for InstanceConnect..." NONE
   (
    printf 'module ec2-instance-connect 1.0;\n\n'
    printf 'require {\n'
    printf '\ttype ssh_keygen_exec_t;\n'
    printf '\ttype sshd_t;\n'
    printf '\ttype http_port_t;\n'
    printf '\tclass process setpgid;\n'
    printf '\tclass tcp_socket name_connect;\n'
    printf '\tclass file map;\n'
    printf '\tclass file { execute execute_no_trans open read };\n'
    printf '}\n\n'
    printf '#============= sshd_t ==============\n\n'
    printf 'allow sshd_t self:process setpgid;\n'
    printf 'allow sshd_t ssh_keygen_exec_t:file map;\n'
    printf 'allow sshd_t ssh_keygen_exec_t:file '
    printf '{ execute execute_no_trans open read };\n'
    printf 'allow sshd_t http_port_t:tcp_socket name_connect;\n'
   ) > "${CHROOTMNT}/tmp/${SELPOL}.te" || \
     err_exit "Failed creating SELinux policy for InstanceConnect"

   err_exit "Compiling/installing SELinux policy for InstanceConnect..." NONE
   chroot "${CHROOTMNT}" /bin/bash -c "
         cd /tmp
         checkmodule -M -m -o ${SELPOL}.mod ${SELPOL}.te
         semodule_package -o ${SELPOL}.pp -m ${SELPOL}.mod
         semodule -i ${SELPOL}.pp && rm ${SELPOL}.*
      " || \
     err_exit "Failed compiling/installing SELinux policy for InstanceConnect"

}

# Install AWS utils from "directory"
function InstallSSMagent {

   if [[ ${SSMAGENT} == "UNDEF" ]]
   then
      err_exit "AWS SSM-Agent not requested for install. Skipping..." NONE
   elif [[ ${SSMAGENT} == *.rpm ]]
   then
      err_exit "Installing AWS SSM-Agent RPM..." NONE
      yum --installroot="${CHROOTMNT}" install -y "${SSMAGENT}" || \
        err_exit "Failed installing AWS SSM-Agent RPM"

      err_exit "Ensuring AWS SSM-Agent is enabled..." NONE
      chroot "${CHROOTMNT}" systemctl enable amazon-ssm-agent.service || \
        err_exit "Failed ensuring AWS SSM-Agent is enabled"
   fi
}


######################
## Main program-flow
######################
OPTIONBUFR=$( getopt \
   -o C:c:d:hi:m:s:\
   --long cli-v1:,cli-v2:,help,instance-connect:,mountpoint:,ssm-agent:,utils-dir: \
   -n "${PROGNAME}" -- "$@")

eval set -- "${OPTIONBUFR}"

###################################
# Parse contents of ${OPTIONBUFR}
###################################
while true
do
   case "$1" in
      -C|--cli-v1)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  CLIV1SOURCE="${2}"
                  shift 2;
                  ;;
            esac
            ;;
      -c|--cli-v2)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  CLIV2SOURCE="${2}"
                  shift 2;
                  ;;
            esac
            ;;
      -d|--utils-dir)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  UTILSDIR="${2}"
                  shift 2;
                  ;;
            esac
            ;;
      -h|--help)
            UsageMsg 0
            ;;
      -i|--instance-connect)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  ICONNECTSRC="${2}"
                  shift 2;
                  ;;
            esac
            ;;
      -m|--mountpoint)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  CHROOTMNT="${2}"
                  shift 2;
                  ;;
            esac
            ;;
      -s|--ssm-agent)
            case "$2" in
               "")
                  err_exit "Error: option required but not specified"
                  shift 2;
                  exit 1
                  ;;
               *)
                  SSMAGENT="${2}"
                  shift 2;
                  ;;
            esac
            ;;
      --)
         shift
         break
         ;;
      *)
         err_exit "Internal error!"
         exit 1
         ;;
   esac
done

###############
# Do the work

# Install AWS CLIv1
InstallCLIv1

# Install AWS CLIv2
InstallCLIv2

# Install AWS SSM-Agent
InstallSSMagent

# Install AWS InstanceConnect
InstallInstanceConnect

# Install AWS utils from directory
InstallFromDir
