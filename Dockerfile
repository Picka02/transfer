FROM ubuntu:20.04

# Install Wine to run Windows executables
RUN dpkg --add-architecture i386 && \
    apt update && \
    apt install -y wine32

# Copy the executable to the container
COPY ./PWN /app

# Set the working directory
WORKDIR /app

# Run the executable
CMD ["wine", "my_executable.exe"]