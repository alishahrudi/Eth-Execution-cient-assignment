FROM ubuntu:latest

# Install dependencies
RUN apt update && apt install -y curl bash

# Copy the start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Use bash as entrypoint to allow script execution
ENTRYPOINT ["/start.sh"]
