FROM debian:bookworm-slim

# Install all runtime deps in one layer to keep layer size minimal.
# NodeSource setup_22.x must run before apt-get install nodejs to ensure
# the NodeSource package (not Debian's older bundled nodejs) is installed.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl gnupg jq shellcheck \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user conjure at UID 1000 (DOCK-02, D-03).
# Container runs unprivileged; callers pass --user $(id -u):$(id -g) for
# mounted-volume file ownership at runtime.
RUN useradd -m -u 1000 -s /bin/bash conjure

ENV CONJURE_HOME=/usr/local/share/conjure

COPY cli/        $CONJURE_HOME/cli/
COPY scripts/    $CONJURE_HOME/scripts/
COPY profiles/   $CONJURE_HOME/profiles/
COPY compliance/ $CONJURE_HOME/compliance/
COPY migrations/ $CONJURE_HOME/migrations/
COPY templates/  $CONJURE_HOME/templates/
COPY lib/        $CONJURE_HOME/lib/
COPY VERSION     $CONJURE_HOME/VERSION

# Make the CLI executable, install a thin wrapper on PATH (mirrors Homebrew
# formula shim pattern), and create the /work mount point as root before
# switching to the non-root user.
RUN chmod +x $CONJURE_HOME/cli/conjure \
    && printf '#!/bin/bash\nexport CONJURE_HOME=/usr/local/share/conjure\nexec /usr/local/share/conjure/cli/conjure "$@"\n' > /usr/local/bin/conjure \
    && chmod +x /usr/local/bin/conjure \
    && mkdir -p /work

USER conjure

WORKDIR /work

ENTRYPOINT ["conjure"]
