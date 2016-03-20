#!/bin/sh
#
# Script to automate basic setup of CHROOT device
#
#################################################################

# Check for arguments
if [[ $# -lt 1 ]]
then
   echo "Missing parameter(s). Aborting..." > /dev/stderr
   exit 1
fi


function ParseOpts() {
   OPTIONBUFR=`getopt -o b:d:r:v: --longoptions bootlabel:,disk:,rootlabel:,vgname: -n ${PROGNAME} -- "$@"`
   
   eval set -- "${OPTIONBUFR}"
   
   ###################################
   # Parse contents of ${OPTIONBUFR}
   ###################################
   while [ true ]
   do
      case "$1" in
         -b|--bootlabel)
   	    case "$2" in
   	       "")
   	          MultiLog "Error: option required but not specified" >&2
   	          shift 2;
   	          exit 1
   	          ;;
   	       *)
                  BOOTLABEL=${2}
   	          shift 2;
   	       ;;
   	    esac
   	    ;;
         -d|--disk)
   	    case "$2" in
   	       "")
   	          MultiLog "Error: option required but not specified" >&2
   	          shift 2;
   	          exit 1
   	          ;;
   	       *)
                  CHROOTDEV=${2}
   	          shift 2;
   	       ;;
   	    esac
   	    ;;
         -r|--rootlabel)
   	    case "$2" in
   	       "")
   	          MultiLog "Error: option required but not specified" >&2
   	          shift 2;
   	          exit 1
   	          ;;
   	       *)
                  ROOTLABEL=${2}
   	          shift 2;
   	       ;;
   	    esac
   	    ;;
         -v|--vgname)
   	    case "$2" in
   	       "")
   	          MultiLog "Error: option required but not specified" >&2
   	          shift 2;
   	          exit 1
   	          ;;
   	       *)
                  VGNAME=${2}
   	          shift 2;
   	       ;;
   	    esac
   	    ;;
         --)
            shift
            break
            ;;
         *)
            MultiLog "Internal error!" >&2
            exit 1
            ;;
      esac
   done
}
