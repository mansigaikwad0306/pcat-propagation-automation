FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    openssh-client \
    sshpass \
    bind-tools

WORKDIR /app

COPY scripts/propagation_post_prod.sh /app/propagation_post_prod.sh
RUN chmod +x /app/propagation_post_prod.sh

ENTRYPOINT ["/app/propagation_post_prod.sh"]
CMD ["--versions-only"]
