# MLOps Assignment 1

Welcome to the BITS MLOps Assignment 1 repository.

---

## 🚀 Setup: Conda Environment

Follow these steps to set up the Conda environment for this project:

1. **Create a new Conda environment** named `mlops-assign1` with Python 3.11:
    ```bash
    conda create -n mlops-assign1 python=3.11
    ```

2. **Activate the environment**:
    ```bash
    conda activate mlops-assign1
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
