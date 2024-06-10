 Use the official Ubuntu 20.04 image from Docker Hub
FROM ubuntu:20.04

# Set non-interactive mode
ARG DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
    python3.8 \
    python3-pip \
    python3.9 \
    nano \
    sudo \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create user and directory
RUN useradd -m -s /bin/bash inferyx && \
    mkdir /app && \
    chown -R inferyx:inferyx /app
    
# Switch to the newly created user
USER inferyx

# Install pip packages for Python 3.8
RUN python3.8 -m pip install --upgrade pip && \
    python3.8 -m pip install numpy pandas matplotlib

# Install pip packages for Python 3.9
RUN python3.9 -m pip install --upgrade pip && \
    python3.9 -m pip install numpy pandas matplotlib

# Set the working directory
WORKDIR /app

# Create volume mount
VOLUME ["/app"]

# Command to run (optional)
CMD ["/bin/bash"]
