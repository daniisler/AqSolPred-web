FROM debian:bookworm-slim

# System dependencies required by pixi, RDKit, and git
RUN apt-get update && apt-get install -y \
    curl \
    bzip2 \
    git \
    sudo \
    dbus-bin \
    libxrender1 \
    libxext6 \
    && mkdir -p /var/lib/dbus \
    && rm -rf /var/lib/apt/lists/*

# Install pixi
RUN curl -fsSL https://pixi.sh/install.sh | sh
ENV PATH="/root/.pixi/bin:${PATH}"

# Set the working directory to the project root
WORKDIR /app

# Copy the environment file first to leverage docker layer caching
COPY aqsolpred-env/pixi.toml aqsolpred-env/pixi.lock ./aqsolpred-env/
RUN pixi install --locked --manifest-path aqsolpred-env/pixi.toml

# Pre-install environment dependencies using pixi
RUN pixi install --manifest-path aqsolpred-env/pixi.toml

# Copy the rest of the repository files (app.py, models, images)
COPY . .

# Expose the streamlit network port
EXPOSE 8501

# Run the app from the root folder using explicit shell invocation
ENTRYPOINT ["pixi", "run", "--manifest-path", "aqsolpred-env/pixi.toml"]
CMD ["streamlit", "run", "streamlit/app.py", "--server.port=8501", "--server.address=0.0.0.0"]
