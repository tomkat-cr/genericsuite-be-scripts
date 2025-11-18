#!/bin/bash
# scripts/install_dev_tools.sh
# 2023-07-11 | CR
#
ERROR_MSG=""

INSTALL_PYENV="1"
INSTALL_PEM_TOOL="1"
INSTALL_AWS_CLI="1"
INSTALL_SAML2AWS="0"

PYTHON_VERSION=""

PEM_TOOL="uv"

if [ "${ERROR_MSG}" = "" ]; then
    export REPO_BASEDIR="`pwd`"
    cd "`dirname "$0"`"
    export SCRIPTS_DIR="`pwd`"
    cd "${REPO_BASEDIR}"
    #
    if [ -f "${BASE_DIR}/.env" ]; then
        set -o allexport; . "${BASE_DIR}/.env" ; set +o allexport ;
    fi
fi

echo "INSTALL_PYENV=${INSTALL_PYENV}"
echo "INSTALL_PEM_TOOL=${INSTALL_PEM_TOOL}"
echo "INSTALL_SAML2AWS=${INSTALL_SAML2AWS}"
echo "INSTALL_AWS_CLI=${INSTALL_AWS_CLI}"
echo "PYTHON_VERSION=${PYTHON_VERSION}"
echo "PEM_TOOL=${PEM_TOOL}"

BASH_PROFILE="${HOME}/.bash_profile"
BASH_SOURCE1="bash"
if [[ -f "${HOME}/.zshrc"  && "$OSTYPE" = "darwin"* ]]; then
    BASH_PROFILE="${HOME}/.zshrc"
    BASH_SOURCE1="zsh"
fi
echo "BASH_PROFILE=${BASH_PROFILE}"
echo "BASH_SOURCE1=${BASH_SOURCE1}"

PYENV_INSTALL_PREFIX=""
MACHINE_ARCHITECTURE=$(arch)
if [[ "${MACHINE_ARCHITECTURE}" = "arm64" && "$OSTYPE" = "darwin"* ]]; then
    PYENV_INSTALL_PREFIX="arch -x86_64"
fi
echo "PYENV_INSTALL_PREFIX=${PYENV_INSTALL_PREFIX}"

if [[ "${PYTHON_VERSION}" = "" && "${INSTALL_PYENV}" = "1" ]]; then
    ERROR_MSG="ERROR: PYTHON_VERSION is not set"
fi

if [[ "${ERROR_MSG}" = "" && "${INSTALL_PYENV}" = "1" ]]; then
    if [ "$OSTYPE" = "linux-gnu" ]; then
        if [ ! -f "$HOME/api-test-tools-os-deps-ready.txt" ]; then
            echo "Installing: ffi, ffi-devel, zlib, and zlib-devel..."
            if sudo yum update -y
            then
                # Compilers and related tools:
                sudo yum groupinstall -y "development tools"
                # If you are on a clean "minimal" install of CentOS you also need the wget tool:
                sudo yum install -y wget
                # Libraries needed during compilation to enable all features of Python:
                if ! sudo yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel expat-devel
                then
                    ERROR_MSG="ERROR: yum install ffi, ffi-devel, zlib, and zlib-devel could not be installed."
                else
                    echo "These tools were yum installed: ffi, ffi-devel, zlib, and zlib-devel"
                    date >"$HOME/api-test-tools-os-deps-ready.txt"
                fi
            else
                if sudo apt-get update -y
                then
                    # Compilers and related tools:
                    sudo apt-get groupinstall -y "development tools"
                    # If you are on a clean "minimal" install of CentOS you also need the wget tool:
                    sudo apt-get install -y wget
                    # Libraries needed during compilation to enable all features of Python:
                    if ! sudo apt-get install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel expat-devel
                    then
                        ERROR_MSG="ERROR: apt-get install ffi, ffi-devel, zlib, and zlib-devel could not be installed."
                    else
                        echo "These tools were apt-get installed: ffi, ffi-devel, zlib, and zlib-devel"
                        date >"$HOME/api-test-tools-os-deps-ready.txt"
                    fi
                else
                    if sudo apk update -y
                    then
                        # Compilers and related tools:
                        sudo apk add --no-cache build-base
                        # If you are on a clean "minimal" install of CentOS you also need the wget tool:
                        sudo apk add wget
                        # Libraries needed during compilation to enable all features of Python:
                        if ! sudo apk add zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel expat-devel
                        then
                            ERROR_MSG="ERROR: apt-get install ffi, ffi-devel, zlib, and zlib-devel could not be installed."
                        else
                            echo "These tools were apt-get installed: ffi, ffi-devel, zlib, and zlib-devel"
                            date >"$HOME/api-test-tools-os-deps-ready.txt"
                        fi
                    fi
                fi
            fi
        fi
    else
        echo ""
        echo "This is not linux... is: ${OSTYPE}. "
        echo "So these tools' installation were not performed: zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel expat-devel"
        echo ""
    fi
fi

if [[ "${ERROR_MSG}" = "" && "${INSTALL_PYENV}" = "1" ]]; then
    if ! pyenv --version
    then
        # install pyenv
        echo ""
        echo "Install pyenv"
        echo ""
        curl https://pyenv.run | bash

        export PYENV_ROOT="$HOME/.pyenv"
        command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"

        if ! pyenv --version
        then
            ERROR_MSG="ERROR: pyenv could not be installed."
        fi
    fi
fi

if [[ "${ERROR_MSG}" = "" && "${INSTALL_PYENV}" = "1" ]]; then
    if ! grep -q 'eval "$(pyenv init --path)"' ${BASH_PROFILE}; then
        # add pyenv to the PATH and enable shims and autocompletion
        echo ""
        echo "Add pyenv to the PATH and enable shims and autocompletion"
        echo ""

        echo "" >> ${BASH_PROFILE}
        echo "# `date`" >> ${BASH_PROFILE}
        echo "# Add pyenv to the PATH and enable shims and autocompletion" >> ${BASH_PROFILE}
        echo "" >> ${BASH_PROFILE}
        echo 'export PYENV_ROOT="${HOME}/.pyenv"' >> ${BASH_PROFILE}
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ${BASH_PROFILE}
        echo 'eval "$(pyenv init --path)"' >> ${BASH_PROFILE}
        echo 'eval "$(pyenv init -)"' >> ${BASH_PROFILE}
        # echo 'eval "$(pyenv virtualenv-init -)"' >> ${BASH_PROFILE}
    fi
fi

if [[ "${ERROR_MSG}" = "" && "${INSTALL_PYENV}" = "1" ]]; then

    if [ ! -d "${HOME}/.pyenv/versions/${PYTHON_VERSION}" ]; then
        # install python version using pyenv
        echo ""
        echo "Install python with: pyenv install ${PYTHON_VERSION}"
        echo ""
        export $PATH="/bin:/usr/bin:$PATH"
        if [ "$OSTYPE" = "linux-gnu" ]; then
            if ! CFLAGS="-I/usr/include/openssl" LDFLAGS="-L/usr/lib" pyenv install ${PYTHON_VERSION}
            then
                ERROR_MSG="ERROR: running 'pyenv install ${PYTHON_VERSION}' (over Linux)"
            fi
        else
            if ! ${PYENV_INSTALL_PREFIX} pyenv install ${PYTHON_VERSION}
            then
                ERROR_MSG="ERROR: running pyenv install ${PYTHON_VERSION}"
            fi
        fi
    fi
fi

if [[ "${ERROR_MSG}" = "" && "${INSTALL_PYENV}" = "1" ]]; then
    echo ""
    echo "Changing python version: pyenv local ${PYTHON_VERSION}"
    echo ""
    if ! pyenv local ${PYTHON_VERSION}
    then
        ERROR_MSG="ERROR: running pyenv local ${PYTHON_VERSION}"
    fi
fi

if [[ "${ERROR_MSG}" = "" && "${INSTALL_PEM_TOOL}" = "1" ]]; then
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        if ! pipenv --version
        then
            echo ""
            echo "Install pipenv"
            echo ""
            if ! pip install --user pipenv
            then
                ERROR_MSG="ERROR: pipenv could not be installed."
            else
                # add pipenv to the bash profile
                ADD_CMD_TO_PROFILE="eval \"$(_PIPENV_COMPLETE=${BASH_SOURCE1}_source pipenv)\""
                if ! grep -q "${ADD_CMD_TO_PROFILE}" ${BASH_PROFILE}; then
                    echo ""
                    echo "Add pipenv to the ${BASH_SOURCE1} profile"
                    echo ""

                    echo "" >> ${BASH_PROFILE}
                    echo "# `date`" >> ${BASH_PROFILE}
                    echo "# Add pipenv init" >> ${BASH_PROFILE}
                    echo "" >> ${BASH_PROFILE}
                    echo "${ADD_CMD_TO_PROFILE}" >> ${BASH_PROFILE}
                fi
            fi
        fi

    elif [ "${PEM_TOOL}" = "poetry" ]; then
        if ! ${HOME}/.local/bin/poetry --version
        then
            echo ""
            echo "Install poetry"
            echo ""
            curl -sSL https://install.python-poetry.org | POETRY_HOME="${HOME}/.local" python3 -

            if ! ${HOME}/.local/bin/poetry --version
            then
                ERROR_MSG="ERROR: poetry could not be installed."
            else
                # add poetry to the PATH
                if ! grep -q 'export PATH="${HOME}/.local/bin:$PATH"' ${BASH_PROFILE}; then
                    echo ""
                    echo "Add poetry to the PATH"
                    echo ""

                    echo "" >> ${BASH_PROFILE}
                    echo "# `date`" >> ${BASH_PROFILE}
                    echo "" >> ${BASH_PROFILE}
                    echo "# Add poetry to the PATH" >> ${BASH_PROFILE}
                    echo "" >> ${BASH_PROFILE}
                    echo 'export PATH="${HOME}/.local/bin:$PATH"' >> ${BASH_PROFILE}
                fi
            fi
        fi

    elif [ "${PEM_TOOL}" = "uv" ]; then
        if ! uv --version
        then
            echo ""
            echo "Install uv"
            echo ""
            # On macOS and Linux.
            curl -LsSf https://astral.sh/uv/install.sh | sh
            if ! uv --version
            then
                ERROR_MSG="ERROR: uv could not be installed."
            fi
        fi
    else
        ERROR_MSG="ERROR: Invalid PEM_TOOL: ${PEM_TOOL}"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    if ! make --version
    then
        # install make
        echo ""
        echo "Install make"
        echo ""

        if [[ "$OSTYPE" = "darwin"* ]]; then
            brew install make
        else
            if ! apt-get -y install make
            then
                if ! yum -y install make
                then
                    if ! apk add make
                    then
                        ERROR_MSG="ERROR: make could not be installed in linux (debian/rhel/alpine)"
                    fi
                fi
            fi  
        fi
        if ! make --version
        then
            ERROR_MSG="ERROR: make could not be installed"
        fi
    fi
fi

if [[ "${ERROR_MSG}" = "" && "${INSTALL_AWS_CLI}" = "1" ]]; then
    if ! aws --version
    then
        sh ${SCRIPTS_DIR}/install_aws_cli.sh
        if ! aws --version
        then
            ERROR_MSG="ERROR: aws-cli could not be installed"
        fi
    fi
fi

if [[ "${ERROR_MSG}" = "" && "${INSTALL_SAML2AWS}" = "1" ]]; then
    if ! saml2aws --version
    then
        sh ${SCRIPTS_DIR}/aws-cli-okta-config.sh
        if ! saml2aws --version
        then
            ERROR_MSG="ERROR: saml2aws could not be installed"
        fi
    fi
fi

echo ""
if [ "${ERROR_MSG}" = "" ]; then
    echo "Done!"
    echo ""
    echo "Reload the shell"
    echo ""
    exec "$SHELL"
else
    echo "${ERROR_MSG}" ;
fi
echo ""
