#!/bin/bash
# Helper script to ensure conda environment is activated

# Function to activate conda environment
activate_conda_env() {
    # Initialize conda for bash/zsh
    if [ -f ~/miniconda3/etc/profile.d/conda.sh ]; then
        source ~/miniconda3/etc/profile.d/conda.sh
    elif [ -f ~/anaconda3/etc/profile.d/conda.sh ]; then
        source ~/anaconda3/etc/profile.d/conda.sh
    elif [ -f /opt/conda/etc/profile.d/conda.sh ]; then
        source /opt/conda/etc/profile.d/conda.sh
    else
        echo "⚠️  Could not find conda installation. Please ensure conda is installed."
        echo "💡 If using different conda installation, modify this script accordingly."
        exit 1
    fi
    
    # Activate the environment
    conda activate mlops-assign
    
    # Verify activation
    if [[ "$CONDA_DEFAULT_ENV" == "mlops-assign" ]]; then
        echo "✅ Successfully activated mlops-assign environment"
        return 0
    else
        echo "❌ Failed to activate mlops-assign environment"
        echo "💡 Please ensure the environment exists: conda create -n mlops-assign python=3.10"
        exit 1
    fi
}

# Export the function for use in other scripts
export -f activate_conda_env

# If script is run directly, activate the environment
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    activate_conda_env
    echo "🏠 mlops-assign environment is now active"
    echo "🚀 You can now run commands like:"
    echo "   python api/app.py"
    echo "   python test_api.py"
    echo "   python test_prometheus.py"
fi
