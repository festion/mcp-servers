#!/bin/bash

# Production vs Development Configuration Comparison Script
# This script downloads production configs and compares them with local development

echo "🔍 Production vs Development Configuration Comparison"
echo "=================================================="

# Create comparison directories
mkdir -p production_sync
mkdir -p comparison_results

echo "📥 Downloading production configuration files..."

# Download core configuration files from production
echo "Downloading core files..."
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get configuration.yaml" && mv configuration.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get templates.yaml" && mv templates.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get input_boolean.yaml" && mv input_boolean.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get input_datetime.yaml" && mv input_datetime.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get input_number.yaml" && mv input_number.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get input_select.yaml" && mv input_select.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get input_text.yaml" && mv input_text.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get sensors.yaml" && mv sensors.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get scripts.yaml" && mv scripts.yaml production_sync/ 2>/dev/null
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "get recorder.yaml" && mv recorder.yaml production_sync/ 2>/dev/null

# Download packages directory
echo "Downloading packages..."
mkdir -p production_sync/packages
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "cd packages; mget *" 2>/dev/null
mv *.yaml production_sync/packages/ 2>/dev/null

# Download automations directory
echo "Downloading automations..."
mkdir -p production_sync/automations
smbclient //192.168.1.155/config -U homeassistant%redflower805 -W homelab -c "cd automations; mget *" 2>/dev/null
mv *.yaml production_sync/automations/ 2>/dev/null

echo "🔍 Comparing configurations..."

# Function to compare files
compare_file() {
    local file=$1
    local dev_file="$file"
    local prod_file="production_sync/$file"
    
    if [[ -f "$dev_file" && -f "$prod_file" ]]; then
        if diff -q "$dev_file" "$prod_file" >/dev/null; then
            echo "✅ $file - MATCH"
        else
            echo "❌ $file - DIFFERENT"
            echo "  Creating detailed comparison..."
            diff -u "$dev_file" "$prod_file" > "comparison_results/${file//\//_}_diff.txt" 2>/dev/null
        fi
    elif [[ -f "$dev_file" && ! -f "$prod_file" ]]; then
        echo "📁 $file - DEV ONLY"
    elif [[ ! -f "$dev_file" && -f "$prod_file" ]]; then
        echo "🏭 $file - PRODUCTION ONLY"
        echo "  Copying from production to dev..."
        cp "$prod_file" "$dev_file"
    else
        echo "❓ $file - NOT FOUND IN EITHER"
    fi
}

echo ""
echo "📋 File-by-file comparison:"
echo "=========================="

# Core configuration files
compare_file "configuration.yaml"
compare_file "templates.yaml"
compare_file "input_boolean.yaml"
compare_file "input_datetime.yaml"
compare_file "input_number.yaml"
compare_file "input_select.yaml"
compare_file "input_text.yaml"
compare_file "sensors.yaml"
compare_file "scripts.yaml"
compare_file "recorder.yaml"

echo ""
echo "📦 Packages comparison:"
echo "====================="

# Compare packages
if [[ -d "packages" ]]; then
    for package in packages/*.yaml; do
        if [[ -f "$package" ]]; then
            package_name=$(basename "$package")
            compare_file "packages/$package_name"
        fi
    done
fi

# Check for production-only packages
if [[ -d "production_sync/packages" ]]; then
    for prod_package in production_sync/packages/*.yaml; do
        if [[ -f "$prod_package" ]]; then
            package_name=$(basename "$prod_package")
            if [[ ! -f "packages/$package_name" ]]; then
                echo "🏭 packages/$package_name - PRODUCTION ONLY"
                echo "  Copying from production to dev..."
                mkdir -p packages
                cp "$prod_package" "packages/$package_name"
            fi
        fi
    done
fi

echo ""
echo "🤖 Automation files comparison:"
echo "==============================="

# Compare automation files
if [[ -d "automations" ]]; then
    for automation in automations/*.yaml; do
        if [[ -f "$automation" ]]; then
            automation_name=$(basename "$automation")
            compare_file "automations/$automation_name"
        fi
    done
fi

# Check for production-only automation files
if [[ -d "production_sync/automations" ]]; then
    for prod_automation in production_sync/automations/*.yaml; do
        if [[ -f "$prod_automation" ]]; then
            automation_name=$(basename "$prod_automation")
            if [[ ! -f "automations/$automation_name" ]]; then
                echo "🏭 automations/$automation_name - PRODUCTION ONLY"
                echo "  Copying from production to dev..."
                mkdir -p automations
                cp "$prod_automation" "automations/$automation_name"
            fi
        fi
    done
fi

echo ""
echo "📊 Summary:"
echo "=========="
echo "Detailed differences saved in comparison_results/ directory"
echo "Review any files marked as DIFFERENT"
echo "Files marked as PRODUCTION ONLY have been copied to development"
echo ""
echo "Run 'ls comparison_results/' to see detailed difference files"