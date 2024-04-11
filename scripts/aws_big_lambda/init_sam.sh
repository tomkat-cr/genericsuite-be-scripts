#!/bin/bash
# scripts/aws_big_lambda/init_sam.sh
# 2024-03-30 | CR - HBD CDM

ask_to_continue() {
    echo "Do you want to overwrite it (Y/n)?"
    read choice
    while [[ ! $choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
}    

copy_file() {
    echo ""
    echo "Copying the '$file_to_copy' file..."
    if [ -f "$target_dir/$file_to_copy" ]; then
        echo "File '"$target_dir/$file_to_copy"' already exists."
        ask_to_continue
        if [[ $choice =~ ^[Yy]$ ]]; then
            echo "Overwriting: cp '$source_dir/$file_to_copy' '$target_dir/$file_to_copy'"
            cp "$source_dir/$file_to_copy" "$target_dir/$file_to_copy"
        fi
    else
        echo "Copying: cp '$source_dir/$file_to_copy' '$target_dir/$file_to_copy'"
        cp "$source_dir/$file_to_copy" "$target_dir/$file_to_copy"
    fi
}

source_dir="./node_modules/genericsuite-be-scripts/scripts"
target_dir="./scripts"

echo ""
echo "Init SAM Templates"
echo ""

echo "Creating the project's 'scripts/aws_big_lambda' directory..."
mkdir -p scripts/aws_big_lambda

echo "Creating the project's 'scripts/aws' directory..."
mkdir -p scripts/aws

echo "Copying the Templates..."

file_to_copy="aws_big_lambda/template-samconfig.toml"
copy_file

file_to_copy="aws_big_lambda/template-sam.yml"
copy_file

file_to_copy="aws/update_additional_envvars.sh"
copy_file
