# Use Node.js base image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy dependency definitions
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application
COPY . .

# Build Strapi app
RUN npm run build

# Expose port Strapi runs on
EXPOSE 1337

# Start Strapi
CMD ["npm", "start"]
