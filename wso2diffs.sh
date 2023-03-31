#!/bin/bash
#set -x

# This is a script intended for comparing two versions of the same WSO2 product to see how they are different in contents.
# 
# Usage: ./wso2diffs.sh [-h] <control_folder> <matching_folder>
# Recursively search <matching_folder> for non-binary files that have changed, and create diffs.
#
# It recursively searches the matching folder and its subfolders for non-binary files that have changed 
# since the last time they were checked, and creates diffs for them. The diffs are saved in a folder called "<matching_folder>_diffs".
# 
# Before performing the search and diff, the script checks if the control folder and matching folder arguments are provided, and it displays 
# a help message if the -h option is provided. The script excludes certain file types (such as exe, dll, png, jpeg, jar, etc.) from the search, 
# and only looks for text files.
#
# After performing the search and diff, the script displays the captured folders (control_folder, matching_folder, and diff_folder) and the results 
# of the search (whether any diff files were created or not). Finally, the script displays the contents of the diff folder.
#
# PLEASE NOTE: This will only do diffs where both folders have the same file. It also misses . (hidden) named files, _ named files, and a few other oddities.
# Double check these results with a raw diff -rq source match |grep  "Only in {match}"
# Example: diff -rq wso2am-3.2.0-orig wso2am-3.2.0-3 |grep "Only in wso2am-3.2.0-3/"



# Define the help message
help_message() {
    echo "Usage: $0 [-h] <control_folder> <matching_folder>"
    echo "Recursively search <matching_folder> for non-binary files that have changed, and create diffs."
    echo ""
    echo "Options:"
    echo "  -h  Display this help message."
    exit 1
}

# Check for help option
if [[ "$1" == "-h" ]]; then
    help_message
fi

# Check that control folder and matching folder are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: control folder and matching folder not provided."
    help_message
fi

# Define the control and matching folders
export control_folder="$1"
export matching_folder="$2"

# Define the folder to save diffs in
export diff_folder="${matching_folder}_diffs"

# Create the diff folder for this run
rm -Rf $diff_folder
if [ ! -d "$diff_folder" ]; then
    mkdir "$diff_folder"
fi


#
echo "== Captured Folders =="
echo "control_folder: ${control_folder}"
echo "matching_folder: ${matching_folder}"
echo "diff_folder: ${diff_folder}"
echo ""

echo "== Hunting =="
# Use find to search for non-binary files in the matching folder and subfolders that have changed
find "$matching_folder" -type f \
    ! -name '*.exe' ! -name '*.dll' \
    ! -name '*.png' ! -name '*.jpeg' \
    ! -name '*.jpg' ! -name '*.class' \
    ! -name '*.gz'  ! -name '*.zip' \
    ! -name '*.jar' ! -name '*.war' \
    ! -name '*.tar' ! -name '*.car' \
    ! -name '*.db'  ! -name 'wso2update*' \
    ! -name '*.bar' ! -name '*.svg' \
    -print0 | xargs -0 -I {} sh -c '
        c_folder=${control_folder}
        #echo "--> 0 DEBUG c_folder: $c_folder"

        # Get the relative path of the file in the matching folder
        m_folder=${matching_folder}
        #echo "--> 0 DEBUG m_folder: $m_folder"

        matching_file="${0#}"
        #echo "--> 0 DEBUG matching_file: $matching_file"

        # Check if the matching file exists and is a text file
        if [ -f "$matching_file" ]; then
            #echo "--> 1 DEBUG: Matching file - $matching_file"
            file_type=$(file -b "$matching_file")
            #echo "--> 2 DEBUG: File type - $file_type"

            # Get the path to the corresponding file in the control folder
            control_file="${control_folder}${matching_file#$matching_folder}"

            # Check if the control file exists and is a text file
            if [ -f "$control_file" ]; then
                #echo "--> 3 DEBUG: Control file - $control_file"
                file_type=$(file -b "$control_file")
                #echo "--> 4 DEBUG: File type - $file_type"

                # Check if the control file exists and is a text file
                #echo "--> 5 DEBUG: getting ready to do diff test using cmp"
                # Check if the files are different
                if ! cmp -s "$matching_file" "$control_file"; then
                    echo "--> 6 DEBUG: cmp says there is a difference."
                    echo "--> 6 DEBUG: Control file - $control_file"
                    echo "--> 6 DEBUG: Matching file - $matching_file"

                    # Create the diff folder
                    diff_file="${matching_file#$matching_folder}"
                    diff_file=${diff_file//\//_}
                    diff_file=${diff_file//_[^/]*_/\/}
                    #diff_file=${diff_file//./_diff.}
                    diff_file="${diff_folder}/${diff_file}"
                    echo "--> 6 DEBUG: diff_file - $diff_file"
                    diff -u "$control_file" "$matching_file" > "$diff_file"
                    echo "=== CREATED DIFF FILE: $diff_file ==="
                fi
            fi
        fi
    ' {} \;

if [ -z "$(ls -A $diff_folder)" ]; then
  echo "No diff files were created."
fi

echo "== Diff Folder =="
ls -la ${diff_folder}
echo ""

echo "== All Done. =="

