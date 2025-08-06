# Use Python 3.10 bullseye image (more stable than slim)
FROM python:3.10-bullseye

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONPATH=/app
ENV FLASK_APP=api/app.py
ENV PORT=5001

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p models logs

# Create a non-root user for security
RUN useradd -m -u 1000 mlops && chown -R mlops:mlops /app
USER mlops

# Expose port
EXPOSE 5001

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5001/api/v1/health/ || exit 1

# Run the application
CMD ["python", "api/app.py"]
