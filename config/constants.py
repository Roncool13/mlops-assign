import os

def find_root_directory():
    """
    Find the root directory of the project by looking for a specific file.
    """
    current_dir = os.path.dirname(os.path.abspath(__file__))
    while current_dir != os.path.dirname(current_dir):
        if os.path.exists(os.path.join(current_dir, "README.md")):
            return current_dir
        current_dir = os.path.dirname(current_dir)
    raise FileNotFoundError("Root directory not found")

# Constants for the project
ROOT_PATH = find_root_directory()
DATA_PATH = os.path.join(ROOT_PATH, "data", "california_housing_dataset", "housing.csv")
REPORTS_PATH = os.path.join(ROOT_PATH, "reports")