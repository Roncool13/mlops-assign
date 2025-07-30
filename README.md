# MLOps Assignment 1

Welcome to the BITS MLOps Assignment 1 repository.

---

## 🚀 Setup: Conda Environment

Follow these steps to set up the Conda environment for this project:

1. **Create a new Conda environment** named `mlops-assign` with Python 3.11:
    ```bash
    conda create -n mlops-assign python=3.10
    ```

2. **Activate the environment**:
    ```bash
    conda activate mlops-assign
    ```

3. **Install required packages**:
    ```bash
    python -m pip install -r requirements.txt
    ```

> **Note:**  
> Ensure you have [Anaconda](https://www.anaconda.com/products/distribution) or [Miniconda](https://docs.conda.io/en/latest/miniconda.html) installed.

---

## 📦 Pull Data from Remote using DVC

[DVC](https://dvc.org/) is used for tracking and versioning data. It allows actual data to be stored in any remote location (like an S3 bucket), while its metadata is tracked in Git. Using this metadata, data can be pulled from the remote using DVC commands.

### 1. Set AWS Credentials

The data is tracked in a public S3 bucket. You can access it with any AWS credentials set as environment variables:

```bash
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_DEFAULT_REGION=""
# Replace empty strings with your own values
```

### 2. Pull Data using DVC

Download the data files tracked by DVC from your remote storage to your local workspace:

```bash
dvc pull
```

For more details, refer to the [DVC documentation on AWS S3 setup](https://dvc.org/doc/user-guide/setup-remote-storage/aws-s3).

---

## 📊 Generate and View EDA Report

This project includes an automated Exploratory Data Analysis (EDA) report generation using the `dataprep` library.

### 1. Install Required Packages

First, ensure you have the necessary packages installed:

```bash
# Install dataprep for EDA report generation
python -m pip install python-Levenshtein
python -m pip install dataprep
```

If you encounter installation issues on macOS (especially with Apple Silicon), try:

```bash
conda install -c conda-forge dataprep
```

> **Note for macOS users:**  
> If you're still facing compilation errors with `levenshtein`, consider using Python 3.10 or below instead of the latest Python version, as newer versions may have compatibility issues with some C extensions.

### 2. Generate EDA Report

To generate the EDA report:

1. Open the notebook: `notebooks/data_preprocess.ipynb`
2. Run all cells to generate the report
3. The report will be saved as `reports/eda_report.html`

### 3. View the Report

Once generated, open the HTML report in your browser:

```bash
# Open the report in your default browser (macOS)
open reports/eda_report.html

# Or open it manually by navigating to the reports folder
```

The EDA report provides comprehensive insights including:
- Dataset overview and statistics
- Missing value analysis
- Correlation matrices
- Distribution plots
- Data quality assessment

---
