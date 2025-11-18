#!/bin/bash
# scripts/run_pem.sh
# 2025-11-08 | CR
#
# Run the selected Python package and dependency management tool (uv, pipenv, and poetry)

PEM_TOOL="uv"

install() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv install
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        poetry install
    elif [ "${PEM_TOOL}" = "uv" ]; then
        uv sync
    fi
}

install_dev() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv install --dev
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        poetry install --dev
    elif [ "${PEM_TOOL}" = "uv" ]; then
        uv sync --dev
    fi
}

update() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv update
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        poetry update
    elif [ "${PEM_TOOL}" = "uv" ]; then
        uv lock --upgrade
        uv sync
    fi
}

update_dev() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv update --dev
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        poetry update --dev
    elif [ "${PEM_TOOL}" = "uv" ]; then
        uv sync --dev
    fi
}

locked_dev() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv install --dev --ignore-pipfile
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        poetry install --all-groups
    elif [ "${PEM_TOOL}" = "uv" ]; then
        uv sync --dev --locked
    fi
}

locked_install() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv install --ignore-pipfile
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        poetry install
    elif [ "${PEM_TOOL}" = "uv" ]; then
        uv sync --locked
    fi
}

lock() {
	${PEM_TOOL} lock
}

clean_rm() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv --rm
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        poetry env remove --all
    elif [ "${PEM_TOOL}" = "uv" ]; then
        rm -rf .venv
    fi
}
    
lint() {
	${PEM_TOOL} run prospector
}

types() {
	${PEM_TOOL} run mypy .
}

coverage() {
	${PEM_TOOL} run coverage run -m unittest discover tests;
	${PEM_TOOL} run coverage report
}

format() {
	${PEM_TOOL} run yapf -i *.py **/*.py **/**/*.py
}

format_check() {
	${PEM_TOOL} run yapf --diff *.py **/*.py **/**/*.py
}

shell() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv shell
        pipenv --python ${PYTHON_VERSION}
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        `poetry env activate`
    elif [ "${PEM_TOOL}" = "uv" ]; then
        uv venv
        if ! source .venv/bin/activate
        then
            if ! . .venv/bin/activate
            then
                echo "ERROR: Could not activate virtual environment."
                exit 1
            fi
        fi
    fi
}

requirements() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        pipenv --python ${PYTHON_VERSION}
        pipenv lock
        pipenv requirements > ${REPO_BASEDIR}/requirements.txt
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        poetry lock
        poetry export -f requirements.txt --output ${REPO_BASEDIR}/requirements.txt --without-hashes
    elif [ "${PEM_TOOL}" = "uv" ]; then
        uv lock
        uv export --no-hashes --no-annotate -o ${REPO_BASEDIR}/requirements.txt
    fi
}

venv_path() {
    if [ "${PEM_TOOL}" = "pipenv" ]; then
        export BASE_VIR_ENVS_PATH=$(pipenv --venv | head -1)
    elif [ "${PEM_TOOL}" = "poetry" ]; then
        export BASE_VIR_ENVS_PATH=$(poetry env info --path)
    elif [ "${PEM_TOOL}" = "uv" ]; then
        export BASE_VIR_ENVS_PATH="${REPO_BASEDIR}/.venv"
    else
        export BASE_VIR_ENVS_PATH=""
    fi
    echo "Virtual environment path: ${BASE_VIR_ENVS_PATH}"
}

run_pycodestyle() {
    ${PEM_TOOL} run pycodestyle .
}

export REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
export SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

ACTION="$1"

echo "Run_pem | ACTION: ${ACTION}"
echo "Python package and dependencies manager tool: ${PEM_TOOL}"

if [ ! -f "${REPO_BASEDIR}/.env" ]; then
    echo "ERROR: .env file not found"
    exit 1
fi
set -o allexport; . "${REPO_BASEDIR}/.env" ; set +o allexport ;

case "${ACTION}" in
    "install")
        install
        ;;
    "install_dev")
        install_dev
        ;;
    "update")
        update
        ;;
    "update_dev")
        update_dev
        ;;
    "locked_dev")
        locked_dev
        ;;
    "locked_install")
        locked_install
        ;;
    "lock")
        lock
        ;;
    "clean_rm")
        clean_rm
        ;;
    "lint")
        lint
        ;;
    "types")
        types
        ;;
    "coverage")
        coverage
        ;;
    "format")
        format
        ;;
    "format_check")
        format_check
        ;;
    "shell")
        shell
        ;;
    "requirements")
        requirements
        ;;
    "venv_path")
        venv_path
        ;;
    "pycodestyle")
        run_pycodestyle
        ;;
    *)
        echo "ERROR: Invalid ACTION: ${ACTION}"
        exit 1
        ;;
esac