FROM debian:trixie-slim

# Upgrade Trixie's base packages and install only required runtime utilities.
# Streamlit 0.69 may call sudo dbus-uuidgen when no machine ID exists.
# Create the ID at build time so the runtime does not need sudo.
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    bzip2 \
    ca-certificates \
    curl \
    dbus-bin \
    libxext6 \
    libxrender1 \
    passwd \
    && dbus-uuidgen --ensure=/etc/machine-id \
    && chmod 0444 /etc/machine-id \
    && groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --home-dir /tmp --no-create-home --shell /usr/sbin/nologin app \
    && rm -rf /var/lib/apt/lists/*

# Install Pixi globally, then remove its installer copy from the root home.
RUN curl -fsSL https://pixi.sh/install.sh | sh \
    && install -m 0755 /root/.pixi/bin/pixi /usr/local/bin/pixi \
    && rm -rf /root/.pixi

ENV PATH="/usr/local/bin:${PATH}" \
    HOME="/tmp" \
    XDG_CACHE_HOME="/tmp/.cache" \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS="false"

# Set the working directory to the project root
WORKDIR /app

# Install from the committed lockfile for repeatable dependency resolution.
COPY aqsolpred-env/pixi.toml aqsolpred-env/pixi.lock ./aqsolpred-env/
# Drop downloaded packages from the image after installation to reduce image size.
RUN pixi install --locked --manifest-path aqsolpred-env/pixi.toml \
    && rm -rf /root/.cache/rattler/cache

# Copy the rest of the repository files (app.py, models, images)
# The app only reads its assets, so run it as an unprivileged account.
COPY . .
USER 10001:10001

# Expose the streamlit network port
EXPOSE 8501

# Run the app from the root folder using explicit shell invocation
ENTRYPOINT ["pixi", "run", "--manifest-path", "aqsolpred-env/pixi.toml"]
CMD ["streamlit", "run", "streamlit/app.py", "--server.port=8501", "--server.address=0.0.0.0"]
