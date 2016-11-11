#!/bin/sh
SPDCHK=$(ethtool eth0 2> /dev/null | grep -q 10000)
CITEST=$(stat -c "%n" /home/* | grep -Ev "(maintuser|lost\+found)")
TARGPART=$(lsblk -bnd /dev/xvda2 | awk '{print $4}')

InstanceMeta() {
   IFS=$'\n'
   DOCDATA=($( curl -s \
      http://169.254.169.254/latest/dynamic/instance-identity/document/
   ))
   unset IFS

   INSTPRIVIP=$(echo ${DOCDATA[1]} | \
      cut -d : -f 2 | \
      sed -e 's/"//g' -e 's/,//'
   )
   INSTAZ=$(echo ${DOCDATA[4]} | \
      cut -d : -f 2 | \
      sed -e 's/"//g' -e 's/,//'
   )
   INSTTYP=$(echo ${DOCDATA[8]} | \
      cut -d : -f 2 | \
      sed -e 's/"//g' -e 's/,//'
   )
   INSTAMI=$(echo ${DOCDATA[9]} | \
      cut -d : -f 2 | \
      sed -e 's/"//g' -e 's/,//'
   )
}

InstanceMeta

echo "=========="
printf "Test Host Name:\t"
hostname
printf "Test Host IP:\t%s\n" ${INSTPRIVIP}
printf "Test Host AZ:\t%s\n" ${INSTAZ}
printf "Test Host Type:\t%s\n" ${INSTTYP}
printf "Test Host AMI:\t%s\n" ${INSTAMI}
echo "=========="

# Can we talk to yum repos
printf "Checking repo availability... "
sudo yum --showduplicates list available kernel > /dev/null && \
  echo -e "\e[32mAvailable!\e[39m" || \
  echo -e "\e[31mNot Available.\e[39m"

# Check if cloud-config ran properly
if [ "${CITEST}" = "" ]
then
   echo -e "CloudInit \e[31mcreated no users\e[39m"
else
   echo -e "CloudInit \e[32mcreated users\e[39m"
fi


# Check if 10Gbps mode is available
if [ "${SPDCHK}" = "" ]
then
   echo -e "10Gbps support \e[31mnot present\e[39m"
else
   echo -e "10Gbps support \e[32mavailable\e[39m"
fi

# Check size of slice hosting root VG
# - test-value equates to the 19.5GB size that is the
#   default for AMIgen-created AMIs
if [ ${TARGPART} -gt 20974665728 ]
then
   echo -e "Growroot support \e[32mfound\e[39m"
else
   echo -e "Growroot support \e[31mmissing\e[39m"
fi
