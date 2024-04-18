#!/bin/bash
# File: scripts/init_json_configs.sh
# 2024-04-14 | CR

ask_yes_or_no() {
    read choice
    while [[ ! $choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
}    

copy_file() {
    echo ""
    echo "Copying file '${file_to_copy}'..."
    source_path="/tmp/${git_repo_tmp_dir}/${git_repo_base_subir}/${file_to_copy}"
    target_path="${target_base_subdir}/${file_to_copy}"
    echo "source_path: ${source_path}"
    echo "target_path: ${target_path}"
    echo ""
    if [ ! -f "${source_path}" ]; then
        echo "ERROR: ${source_path} doesn't exist"
    else
        if [ -f "${target_path}" ]; then
            echo "Target file '${target_path}' exists. Do you want to overwrite it (y/n)?"
            ask_yes_or_no
            if [[ $choice =~ ^[Yy]$ ]]; then
                echo "  ...overwrite existing file"
                cp ${source_path} ${target_path}
            fi
        else
            cp ${source_path} ${target_path}
        fi
    fi
}

mount_git_repo() {
    echo ""
    echo "Mount Git repo '${git_repo_url}' in /tmp/${git_repo_tmp_dir}..."
    echo ""
    cd /tmp/
    if [ -d "${git_repo_tmp_dir}" ]; then
        echo "  ...remove existing directory"
        rm -rf ${git_repo_tmp_dir}
    fi
    git clone ${git_repo_url} ${git_repo_tmp_dir}
    cd ${git_repo_tmp_dir}
    echo "Done..."
}

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;
cd "${REPO_BASEDIR}"

if [ -f "${REPO_BASEDIR}/.env" ]; then
    ENV_FILESPEC="${REPO_BASEDIR}/.env"
else
    echo "ERROR .env file doesn't exist"
    exit 1
fi
set -o allexport; source ${ENV_FILESPEC}; set +o allexport ;

git_repo_url="https://github.com/tomkat-cr/genericsuite-fe.git"
git_repo_tmp_dir="genericsuite-fe-tmp"
git_repo_base_subir="src/configs"
target_base_subdir="${REPO_BASEDIR}/${GIT_SUBMODULE_LOCAL_PATH}"

echo "Initialize JSON configuration files on Git Submodule directory:"
echo ""
echo "git_repo_url: ${git_repo_url}"
echo "git_repo_tmp_dir: ${git_repo_tmp_dir}"
echo "git_repo_base_subir: ${git_repo_base_subir}"
echo "target_base_subdir: ${target_base_subdir}"

if [ ! -d "${target_base_subdir}" ]; then
    echo ""
    echo "ERROR: 'Target base directory '${target_base_subdir}' doesn't exist."
    echo "You should run 'make add_submodules' to create it."
    exit 1
fi

mount_git_repo

echo ""
echo "Creating directory: ${target_base_subdir}/frontend"
mkdir -p ${target_base_subdir}/frontend
echo "Creating directory: ${target_base_subdir}/backend"
mkdir -p ${target_base_subdir}/backend

file_to_copy="backend/app_main_menu.json"
copy_file
file_to_copy="backend/endpoints.json"
copy_file
file_to_copy="backend/general_config.json"
copy_file
file_to_copy="backend/users.json"
copy_file
file_to_copy="backend/users_config.json"
copy_file

file_to_copy="frontend/app_constants.json"
copy_file
file_to_copy="frontend/general_config.json"
copy_file
file_to_copy="frontend/general_constants.json"
copy_file
file_to_copy="frontend/users.json"
copy_file
file_to_copy="frontend/users_config.json"
copy_file
file_to_copy="frontend/users_profile.json"
copy_file

rm -rf "/tmp/${git_repo_tmp_dir}"

echo "Done..."
echo ""
