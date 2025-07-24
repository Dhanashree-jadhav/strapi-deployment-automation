# Use a lightweight Node image
FROM node:18-alpine

# Create and set working directory
WORKDIR /app

# Copy everything from your repo (even if empty)
COPY . .

# Run a simple command to verify the image builds
CMD ["node", "-e", "console.log('✅ Docker image built successfully!')"]
