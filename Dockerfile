FROM ubuntu:24.04

ARG USERNAME=hluser
ARG USER_UID=10000
ARG USER_GID=$USER_UID

# Define URLs as environment variables
ARG PUB_KEY_URL=https://raw.githubusercontent.com/hyperliquid-dex/node/refs/heads/main/pub_key.asc
ARG HL_VISOR_URL=https://binaries.hyperliquid.xyz/Mainnet/hl-visor
ARG HL_VISOR_ASC_URL=https://binaries.hyperliquid.xyz/Mainnet/hl-visor.asc


# Create user and install dependencies
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update -y && apt-get install -y curl gnupg jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/$USERNAME/hl/data && chown -R $USERNAME:$USERNAME /home/$USERNAME/hl

USER $USERNAME
WORKDIR /home/$USERNAME

# Configure chain to testnet
RUN echo '{"chain": "Mainnet"}' > /home/$USERNAME/visor.json

# Import GPG public key
RUN curl -o /home/$USERNAME/pub_key.asc $PUB_KEY_URL \
    && gpg --import /home/$USERNAME/pub_key.asc

# Download and verify hl-visor binary
RUN curl -o /home/$USERNAME/hl-visor $HL_VISOR_URL
RUN curl -o /home/$USERNAME/hl-visor.asc $HL_VISOR_ASC_URL
RUN chmod a+x /home/$USERNAME/hl-visor
RUN gpg --verify /home/$USERNAME/hl-visor.asc /home/$USERNAME/hl-visor
RUN curl -X POST --header "Content-Type: application/json" --data '{ "type": "gossipRootIps" }' https://api.hyperliquid.xyz/info | jq --monochrome-output -c '{ "root_node_ips": [{"Ip": .[]}], "try_new_peers": true, "chain": "Mainnet", "reserved_peer_ips": ["5.6.7.8"] }'  > /home/$USERNAME/override_gossip_config.json


# Expose gossip ports
EXPOSE 4000-4010

ENV RUST_BACKTRACE=full

# Run a non-validating node
ENTRYPOINT ["/home/hluser/hl-visor", "run-non-validator", "--replica-cmds-style", "recent-actions", "--write-fills", "--batch-by-block"]
