# Use a small Python base image
FROM python:3.12-slim

# Set working directory inside the container
WORKDIR /app

# Install dependencies first (better caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app
COPY . .

# Flask will listen on 8080
EXPOSE 8080

# Command to start the app
CMD ["python", "app.py"]
