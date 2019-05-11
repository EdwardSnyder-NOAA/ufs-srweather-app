#!/bin/sh -l

#
#-----------------------------------------------------------------------
#
# This script gets from the mass store, aka HPSS, the nemsio files out-
# put by the GFS that are needed to generate NetCDF files containing the
# initial condition and surface fields that are inputs to the FV3SAR.  
# It places these files in a subdirectory under the one specified by EX-
# TRN_MDL_FILES_BASEDIR_ICSSURF.
#
#-----------------------------------------------------------------------
#

#
#-----------------------------------------------------------------------
#
# Source the variable definitions script.                                                                                                         
#
#-----------------------------------------------------------------------
#
. $SCRIPT_VAR_DEFNS_FP
#
#-----------------------------------------------------------------------
#
# Source function definition files.
#
#-----------------------------------------------------------------------
#
. $USHDIR/source_funcs.sh
#
#-----------------------------------------------------------------------
#
# Source function that sets the output file names needed from the exter-
# nal model and, if relevant, the full path to the archive file on HPSS. 
#
#-----------------------------------------------------------------------
#
. $USHDIR/get_extrn_mdl_file_dir_info.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u -x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Set the parameter that determines whether we want to get analysis or
# forecast files.  This depends on whether we want these files to gene-
# rate initial condition and surface field files or lateral boundary 
# condition files for the FV3SAR.
#
#-----------------------------------------------------------------------
#
#EXTRN_MDL_NAME="$1"
#ANL_OR_FCST="$2"

if [ "$ICSSURF_OR_LBCS" = "ICSSURF" ]; then
  ANL_OR_FCST="anl"
elif [ "$ICSSURF_OR_LBCS" = "LBCS" ]; then
  ANL_OR_FCST="fcst"
else
  print_err_msg_exit "\
Bad value for ANL_OR_FCST:
  ANL_OR_FCST = \"$ANL_OR_FCST\"
"
fi
#
#-----------------------------------------------------------------------
#
# Create the directory EXTRN_MDL_FILES_BASEDIR_ICSSURF if it doesn't al-
# ready exist.  This is the directory in which we will create a subdi-
# rectory for each cycle (i.e. for each CDATE) in which to store the 
# output files from the external model .
#
#-----------------------------------------------------------------------
#
if [ "$ANL_OR_FCST" = "anl" ]; then
  mkdir_vrfy -p "$EXTRN_MDL_FILES_BASEDIR_ICSSURF"
  EXTRN_MDL_FILES_DIR="$EXTRN_MDL_FILES_BASEDIR_ICSSURF/$CDATE"
elif [ "$ANL_OR_FCST" = "fcst" ]; then
  mkdir_vrfy -p "$EXTRN_MDL_FILES_BASEDIR_LBCS"
  EXTRN_MDL_FILES_DIR="$EXTRN_MDL_FILES_BASEDIR_LBCS/$CDATE"
fi
#
#-----------------------------------------------------------------------
#
# Create the directory specific to the current forecast (whose starting
# date and time is specified in CDATE) in which to store the GFS output
# files.  Then change location to that directory.
#
#-----------------------------------------------------------------------
#
mkdir_vrfy -p "$EXTRN_MDL_FILES_DIR"
cd_vrfy $EXTRN_MDL_FILES_DIR || print_err_msg_exit "\
Could not change directory to EXTRN_MDL_FILES_DIR:
  EXTRN_MDL_FILES_DIR = \"$EXTRN_MDL_FILES_DIR\""
#
#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
#
output_fn="output_vars.sh"
output_var_names=( \
"EXTRN_MDL_FNS" "ARCV_FILE_FMT" "ARCV_FP" "ARCVREL_DIR" "EXTRN_MDL_FILES_SYSDIR" \
)
get_extrn_mdl_file_dir_info \
  "$EXTRN_MDL_NAME" "$ANL_OR_FCST" "$CDATE" \
  "$output_fn" ${output_var_names[@]}
. $output_fn
rm_vrfy $output_fn
#
# As a check, print out the variables and their values set by the above 
# function call.
#
printf "\n"
for output_var_name in "${output_var_names[@]}"; do
  tmp="$output_var_name[@]"
  elems=$( printf "\"%s\" " "${!tmp}" )
  printf "$output_var_name = $elems\n"
done
#
#-----------------------------------------------------------------------
#
# We will first check whether the external model output files exist on
# the system disk (and are older than a certain age).  If so, we will 
# simply copy them from the system disk to the location specified by 
# EXTRN_MDL_FILES_DIR.  If not, we will look for them on HPSS.
#
# Start by setting EXTRN_MDL_FPS to the full paths that the external mo-
# del output files would have if they existed on the system disk.  Then
# count the number of such files that actually exist on disk (i.e. have
# not yet been scrubbed) and are older than a specified age (to make 
# sure that they are not still being written to).
#
#-----------------------------------------------------------------------
#
num_files_to_copy="${#EXTRN_MDL_FNS[@]}"
prefix="$EXTRN_MDL_FILES_SYSDIR/"
EXTRN_MDL_FPS=( "${EXTRN_MDL_FNS[@]/#/$prefix}" )

num_files_found_on_disk="0"
min_age="5"  # Minimum file age in minutes.
for FP in "${EXTRN_MDL_FPS[@]}"; do
  if [ -f "$FP" ]; then
    printf "File \"%s\" exists on system disk..." "$FP"
    if [ $( find "$FP" -mmin +5 ) ]; then
      printf " and is older than $min_age minutes!"
      num_files_found_on_disk=$(( num_files_found_on_disk+1 ))
    else
      printf " but is NOT older than $min_age minutes!"
    fi
  else
    printf "File \"%s\" does NOT exist on system disk!" "$FP"
  fi
done

#echo
#echo "num_files_to_copy = $num_files_to_copy"
#echo "num_files_found_on_disk = $num_files_found_on_disk"
#
#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
#
if [ "$num_files_found_on_disk" -eq "$num_files_to_copy" ]; then
  DATA_SRC="disk"
else
  DATA_SRC="HPSS"
fi
#
#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
#
EXTRN_MDL_FNS_str=$( printf "\"%s\" " "${EXTRN_MDL_FNS[@]}" )
EXTRN_MDL_FNS_str="( $EXTRN_MDL_FNS_str)"

if [ "$DATA_SRC" = "disk" ]; then

  print_info_msg "
Copying model output files (EXTRN_MDL_FNS) from system directory on disk 
(EXTRN_MDL_FILES_SYSDIR) to local directory (EXTRN_MDL_FILES_DIR):
  EXTRN_MDL_FILES_SYSDIR = \"$EXTRN_MDL_FILES_SYSDIR\"
  EXTRN_MDL_FNS = $EXTRN_MDL_FNS_str
  EXTRN_MDL_FILES_DIR = \"$EXTRN_MDL_FILES_DIR\"
"

  cp_vrfy ${EXTRN_MDL_FPS[@]} $EXTRN_MDL_FILES_DIR
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
  print_info_msg "
========================================================================
External model files needed for generating initial condition and surface 
fields for the FV3SAR successfully copied from system disk!!!
========================================================================"
#
#-----------------------------------------------------------------------
#
#
#
#-----------------------------------------------------------------------
#
elif [ "$DATA_SRC" = "HPSS" ]; then

  print_info_msg "
Fetching model output files (EXTRN_MDL_FNS) from archive file on HPSS 
(ARCV_FP) to local directory (EXTRN_MDL_FILES_DIR):
  ARCV_FP = \"$ARCV_FP\"
  EXTRN_MDL_FNS = $EXTRN_MDL_FNS_str
  EXTRN_MDL_FILES_DIR = \"$EXTRN_MDL_FILES_DIR\"
"

  prefix="$ARCVREL_DIR/"
  EXTRN_MDL_FPS=( "${EXTRN_MDL_FNS[@]/#/$prefix}" )
#
#-----------------------------------------------------------------------
#
# Load necessary modules.
#
#-----------------------------------------------------------------------
#
  { save_shell_opts; set +x; } > /dev/null 2>&1
  module load hpss
  { restore_shell_opts; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Consider the case of the archive file to be fetched from HPSS being 
# in tar format.
#
#-----------------------------------------------------------------------
#
  if [ "$ARCV_FILE_FMT" = "tar" ]; then
#
#-----------------------------------------------------------------------
#
# Before trying to extract the external model output files from the tar
# file on HPSS, check that the tar file contains all the output files 
# (and indirectly check that the tar file exists on HPSS).  The follow-
# ing htar command lists in the log file HTAR_LOG_FN the names of those 
# output files that exist in the tar file.  Note that the command will 
# fail if the tar file itself doesn't exist on HPSS, but it won't fail
# if any of the output files don't exist in the tar file.  In the latter
# case, the missing files' names simply won't appear in the log file 
# (which is checked for later below).
#
#-----------------------------------------------------------------------
#
    HTAR_LOG_FN="log.htar_tvf"
    htar -tvf ${ARCV_FP} ${EXTRN_MDL_FPS[@]} >& ${HTAR_LOG_FN} || \
    print_err_msg_exit "\
htar file list operation (\"htar -tvf ...\") failed.  Check the log file 
HTAR_LOG_FN in the directory EXTRN_MDL_FILES_DIR for details:
  EXTRN_MDL_FILES_DIR = \"$EXTRN_MDL_FILES_DIR\"
  HTAR_LOG_FN = \"$HTAR_LOG_FN\"
"
#
#-----------------------------------------------------------------------
#
# Check that the log file from the htar command above contains the name
# of each external model output file.  If any are missing, then the cor-
# responding files are not in the tar file (and thus cannot be extract-
# ed).  In that case, print out a message and exit the script because 
# initial condition and surface field files for the FV3SAR cannot be 
# generated without all the external model output files.
#
#-----------------------------------------------------------------------
#
    for FP in "${EXTRN_MDL_FPS[@]}"; do
      grep -n "${FP}" "${HTAR_LOG_FN}" > /dev/null 2>&1 || \
      print_err_msg_exit "\
External model output file FP not found in tar archive file ARCV_FP:
  ARCV_FP = \"$ARCV_FP\"
  FP = \"$FP\"
Check the log file HTAR_LOG_FN in the directory EXTRN_MDL_FILES_DIR for 
details:
  EXTRN_MDL_FILES_DIR = \"$EXTRN_MDL_FILES_DIR\"
  HTAR_LOG_FN = \"$HTAR_LOG_FN\"
"
    done
#
#-----------------------------------------------------------------------
#
# Extract the external model output files from the tar file on HPSS.
#
#-----------------------------------------------------------------------
#
    HTAR_LOG_FN="log.htar_xvf"
    htar -xvf ${ARCV_FP} ${EXTRN_MDL_FPS[@]} >& ${HTAR_LOG_FN} || \
    print_err_msg_exit "\
htar file extract operation (\"htar -xvf ...\") failed.  Check the log 
file HTAR_LOG_FN in the directory EXTRN_MDL_FILES_DIR for details:
  EXTRN_MDL_FILES_DIR = \"$EXTRN_MDL_FILES_DIR\"
  HTAR_LOG_FN = \"$HTAR_LOG_FN\"
"
#
#-----------------------------------------------------------------------
#
# Note that the htar file extract operation above may return with a 0 
# exit code (success) even if one or more (or all) external model output
# files were not extracted.  The names of those files that were not ex-
# tracted will not be listed in the log file.  Thus, we now check that 
# the log file from the htar command above contains the name of each 
# output file.  If any are missing, we print out a message and exit the 
# script because initial condition and surface field files for the FV3-
# SAR cannot be generated without all the external model output files.
#
#-----------------------------------------------------------------------
#
    for FP in "${EXTRN_MDL_FPS[@]}"; do
#
# If the file path is absolute (i.e. starts with a "/"), then drop the
# leading "/" because htar strips it before writing the file path to the
# log file.
#
      if [ "${FP:0:1}" = "/" ]; then
        FP=${FP:1}
      fi

      grep -n "${FP}" "${HTAR_LOG_FN}" > /dev/null 2>&1 || \
      print_err_msg_exit "\
External model output file FP not extracted from tar archive file ARCV_FP:
  ARCV_FP = \"$ARCV_FP\"
  FP = \"$FP\"
Check the log file HTAR_LOG_FN in the directory EXTRN_MDL_FILES_DIR for 
details:
  EXTRN_MDL_FILES_DIR = \"$EXTRN_MDL_FILES_DIR\"
  HTAR_LOG_FN = \"$HTAR_LOG_FN\"
"

    done
#
#-----------------------------------------------------------------------
#
# If ARCVREL_DIR is not set to the current directory (i.e. it is not 
# equal to "."), then the htar command will have created the subdirecto-
# ry "./${ARCVREL_DIR}" under the current directory and placed the ex-
# tracted files there.  In that case, we move these extracted files back
# to the current directory and then remove the subdirectory created by 
# htar.
#
#-----------------------------------------------------------------------
#
    if [ "$ARCVREL_DIR" != "." ]; then
#
# The code below works if the first character of ARCVREL_DIR is a "/",
# which is the only case encountered thus far.  The code may have to be
# modified to accomodate the case of the first character of ARCVREL_DIR
# not being a "/".
#
      if [ "${ARCVREL_DIR:0:1}" = "/" ]; then

        mv_vrfy .$ARCVREL_DIR/* .
#
# Get the first subdirectory in ARCVREL_DIR, i.e. the directory after
# the first forward slash.  This is the subdirectory that we want to re-
# move.
#
        subdir_to_remove=$( printf "%s" "${ARCVREL_DIR}" | sed -r 's|^\/([^/]*).*|\1|' )
        rm_vrfy -rf ./$subdir_to_remove
#
# If ARCVREL_DIR does not start with a "/" (and it is not equal to "."), 
# then print out an error message and exit.
#
      else

        print_err_msg_exit "\
The archive-relative directory (i.e. the directory \"within\" the tar file
ARCV_FP specified by ARCVREL_DIR is not the current directory (i.e. it 
is not \".\"), and it does not start with a \"/\":
  ARCV_FP = \"$ARCV_FP\"
  ARCVREL_DIR = \"$ARCVREL_DIR\"
The current script must be modified to account for this case.
"
      fi

    fi
#
#-----------------------------------------------------------------------
#
# Consider the case of the archive file to be fetched from HPSS being 
# in zip format.
#
#-----------------------------------------------------------------------
#
  elif [ "$ARCV_FILE_FMT" = "zip" ]; then
  
    HSI_LOG_FN="log.hsi_get"
    hsi get ${ARCV_FP} >& ${HSI_LOG_FN} || \
    print_err_msg_exit "\
hsi file get operation (\"hsi get ...\") failed.  Check the log file 
HSI_LOG_FN in the directory EXTRN_MDL_FILES_DIR for details:
  EXTRN_MDL_FILES_DIR = \"$EXTRN_MDL_FILES_DIR\"
  HSI_LOG_FN = \"$HSI_LOG_FN\"
"
  
  fi
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
  print_info_msg "\

========================================================================
External model files needed for generating initial condition and surface 
fields for the FV3SAR successfully fetched from HPSS!!!
========================================================================"

fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1
