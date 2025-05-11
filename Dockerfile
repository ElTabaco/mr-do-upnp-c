# Dockerfile
FROM debian:latest

# Install necessary packages
RUN apt-get update && \
    apt-get install -y build-essential libupnp-dev

# Copy the renderer source code into the container
COPY renderer.c /app/renderer.c

# Set working directory
WORKDIR /app

# Compile the renderer code
RUN gcc -o renderer source/renderer.c -lupnp

# Expose the UPnP port (can be overridden at runtime)
ARG PORT=49152
ENV PORT=${PORT}
EXPOSE ${PORT}

# Run the renderer, using PORT as an argument
CMD ["sh", "-c", "./renderer $PORT"]
